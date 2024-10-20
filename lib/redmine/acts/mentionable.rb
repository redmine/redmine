# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2023 Jean-Philippe Lang
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
    module Mentionable
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def acts_as_mentionable(options = {})
          class_attribute :mentionable_attributes
          self.mentionable_attributes = options[:attributes]

          attr_accessor :mentioned_users

          send :include, Redmine::Acts::Mentionable::InstanceMethods

          after_save :parse_mentions
        end
      end

      module InstanceMethods
        def self.included(base)
          base.extend ClassMethods
        end

        def notified_mentions
          notified = mentioned_users.to_a
          notified.reject! {|user| user.mail.blank? || user.mail_notification == 'none'}
          if respond_to?(:visible?)
            notified.select! {|user| visible?(user)}
          end
          notified
        end

        private

        def parse_mentions
          mentionable_attrs = self.mentionable_attributes
          saved_mentionable_attrs = self.saved_changes.select{|a| mentionable_attrs.include?(a)}

          saved_mentionable_attrs.each_value do |attr|
            old_value, new_value =  attr
            get_mentioned_users(old_value, new_value)
          end
        end

        def get_mentioned_users(old_content, new_content)
          self.mentioned_users = []

          previous_matches =  scan_for_mentioned_users(old_content)
          current_matches = scan_for_mentioned_users(new_content)
          new_matches = (current_matches - previous_matches).flatten

          if new_matches.any?
            self.mentioned_users = User.visible.active.where(login: new_matches)
          end
        end

        def scan_for_mentioned_users(content)
          return [] if content.nil?

          # remove quoted text
          content = content.gsub(%r{\r\n(?:\>\s)+(.*?)\r\n}m, '')

          text_formatting = Setting.text_formatting
          # Remove text wrapped in pre tags based on text formatting
          case text_formatting
          when 'textile'
            content = content.gsub(%r{<pre>(.*?)</pre>}m, '')
          when 'common_mark'
            content = content.gsub(%r{(~~~|```)(.*?)(~~~|```)}m, '')
          end

          content.scan(MENTION_PATTERN).flatten
        end

        MENTION_PATTERN = /
          (?:^|\W)
          @([A-Za-z0-9_\-@\.]*?)
          (?=
            (?=[[:punct:]][^A-Za-z0-9_\/])|
            \s|
            [[:punct:]]?
            $
          )
        /ix
      end
    end
  end
end
