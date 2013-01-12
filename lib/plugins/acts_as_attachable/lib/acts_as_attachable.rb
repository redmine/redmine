# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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
    module Attachable
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def acts_as_attachable(options = {})
          cattr_accessor :attachable_options
          self.attachable_options = {}
          attachable_options[:view_permission] = options.delete(:view_permission) || "view_#{self.name.pluralize.underscore}".to_sym
          attachable_options[:delete_permission] = options.delete(:delete_permission) || "edit_#{self.name.pluralize.underscore}".to_sym

          has_many :attachments, options.merge(:as => :container,
                                               :order => "#{Attachment.table_name}.created_on ASC, #{Attachment.table_name}.id ASC",
                                               :dependent => :destroy)
          send :include, Redmine::Acts::Attachable::InstanceMethods
          before_save :attach_saved_attachments
        end
      end

      module InstanceMethods
        def self.included(base)
          base.extend ClassMethods
        end

        def attachments_visible?(user=User.current)
          (respond_to?(:visible?) ? visible?(user) : true) &&
            user.allowed_to?(self.class.attachable_options[:view_permission], self.project)
        end

        def attachments_deletable?(user=User.current)
          (respond_to?(:visible?) ? visible?(user) : true) &&
            user.allowed_to?(self.class.attachable_options[:delete_permission], self.project)
        end

        def saved_attachments
          @saved_attachments ||= []
        end

        def unsaved_attachments
          @unsaved_attachments ||= []
        end

        def save_attachments(attachments, author=User.current)
          if attachments.is_a?(Hash)
            attachments = attachments.stringify_keys
            attachments = attachments.to_a.sort {|a, b|
              if a.first.to_i > 0 && b.first.to_i > 0
                a.first.to_i <=> b.first.to_i
              elsif a.first.to_i > 0
                1
              elsif b.first.to_i > 0
                -1
              else
                a.first <=> b.first
              end
            }
            attachments = attachments.map(&:last)
          end
          if attachments.is_a?(Array)
            attachments.each do |attachment|
              next unless attachment.is_a?(Hash)
              a = nil
              if file = attachment['file']
                next unless file.size > 0
                a = Attachment.create(:file => file, :author => author)
              elsif token = attachment['token']
                a = Attachment.find_by_token(token)
                next unless a
                a.filename = attachment['filename'] unless attachment['filename'].blank?
                a.content_type = attachment['content_type']
              end
              next unless a
              a.description = attachment['description'].to_s.strip
              if a.new_record?
                unsaved_attachments << a
              else
                saved_attachments << a
              end
            end
          end
          {:files => saved_attachments, :unsaved => unsaved_attachments}
        end

        def attach_saved_attachments
          saved_attachments.each do |attachment|
            self.attachments << attachment
          end
        end

        module ClassMethods
        end
      end
    end
  end
end
