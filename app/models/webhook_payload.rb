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

# Webhook payload
class WebhookPayload
  attr_accessor :event, :object, :user

  def initialize(event, object, user)
    self.event = event
    self.object = object
    self.user = user
  end

  def self.register_model(model, model_events)
    raise ArgumentError, "model_events must be Array" unless model_events.is_a?(Array)

    @events ||= {}
    @events[model.model_name.singular.to_sym] = model_events
  end

  def self.events
    @events ||= {}
  end

  def to_h
    type, action = event.split('.')
    if self.class.events[type.to_sym]&.include?(action)
      object.webhook_payload(user, action)
    else
      raise ArgumentError, "invalid event: #{event}"
    end
  end

  # given a path to an API template (relative to RAILS_ROOT), renders it and returns the resulting hash
  class ApiRenderer
    include ApplicationHelper
    include CustomFieldsHelper
    attr_accessor :path, :params, :user

    DummyRequest = Struct.new(:params)

    def initialize(path, user, params = nil)
      self.path = path
      self.user = user
      self.params = params || {}
    end

    def to_h(**ivars)
      req = DummyRequest.new(params)
      api = Redmine::Views::Builders::Json.new(req, nil)
      ivars.each { |k, v| instance_variable_set :"@#{k}", v }
      original_user = User.current
      begin
        User.current = self.user
        instance_eval(File.read(Rails.root.join(path)), path, 1)
      ensure
        User.current = original_user
      end
    end
  end
end
