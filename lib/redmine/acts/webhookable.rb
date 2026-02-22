# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module Redmine
  module Acts
    module Webhookable
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def acts_as_webhookable(events = %w(created updated deleted))
          events = Array(events).map(&:to_s)
          WebhookPayload.register_model(self, events)

          events.each do |event|
            case event
            when 'created'
              after_create_commit ->{ Webhook.trigger(event_name('created'), self) }
            when 'updated'
              after_update_commit ->{ Webhook.trigger(event_name('updated'), self) }
            when 'deleted'
              after_destroy_commit ->{ Webhook.trigger(event_name('deleted'), self) }
            end
          end

          include Redmine::Acts::Webhookable::InstanceMethods
        end
      end

      module InstanceMethods
        def event_name(action)
          "#{self.class.model_name.singular}.#{action}"
        end

        def webhook_payload(user, action)
          {
            type: event_name(action),
            timestamp: webhook_payload_timestamp(action),
            data: {
              self.class.model_name.singular.to_sym =>
                WebhookPayload::ApiRenderer.new(webhook_payload_api_template, user).to_h(**webhook_payload_ivars)
            }
          }
        end

        def webhook_payload_ivars
          { self.class.model_name.singular.to_sym => self }
        end

        def webhook_payload_api_template
          "app/views/#{self.class.model_name.plural}/show.api.rsb"
        end

        def webhook_payload_timestamp(action)
          ts = case action
               when 'created'
                 created_on
               when 'updated'
                 updated_on
               else
                 Time.now
               end

          ts.iso8601
        end
      end
    end
  end
end
