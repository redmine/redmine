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
    module Customizable
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def acts_as_customizable(options = {})
          return if self.included_modules.include?(Redmine::Acts::Customizable::InstanceMethods)
          cattr_accessor :customizable_options
          self.customizable_options = options
          before_destroy :store_attachment_custom_value_ids
          has_many :custom_values, lambda {includes(:custom_field)},
                                   :as => :customized,
                                   :inverse_of => :customized,
                                   :dependent => :delete_all,
                                   :validate => false

          send :include, Redmine::Acts::Customizable::InstanceMethods
          validate :validate_custom_field_values
          after_save :save_custom_field_values
          after_destroy :destroy_custom_value_attachments
        end
      end

      module InstanceMethods
        def self.included(base)
          base.extend ClassMethods
        end

        def available_custom_fields
          CustomField.where("type = '#{self.class.name}CustomField'").sorted.to_a
        end

        # Sets the values of the object's custom fields
        # values is an array like [{'id' => 1, 'value' => 'foo'}, {'id' => 2, 'value' => 'bar'}]
        def custom_fields=(values)
          values_to_hash = values.inject({}) do |hash, v|
            v = v.stringify_keys
            if v['id'] && v.has_key?('value')
              hash[v['id']] = v['value']
            end
            hash
          end
          self.custom_field_values = values_to_hash
        end

        # Sets the values of the object's custom fields
        # values is a hash like {'1' => 'foo', 2 => 'bar'}
        def custom_field_values=(values)
          values = values.stringify_keys

          custom_field_values.each do |custom_field_value|
            key = custom_field_value.custom_field_id.to_s
            if values.has_key?(key)
              custom_field_value.value = values[key]
            end
          end
          @custom_field_values_changed = true
        end

        def custom_field_values
          @custom_field_values ||= available_custom_fields.collect do |field|
            x = CustomFieldValue.new
            x.custom_field = field
            x.customized = self
            if field.multiple?
              values = custom_values.select { |v| v.custom_field == field }
              if values.empty?
                values << custom_values.build(:customized => self, :custom_field => field)
              end
              x.instance_variable_set("@value", values.map(&:value))
            else
              cv = custom_values.detect { |v| v.custom_field == field }
              cv ||= custom_values.build(:customized => self, :custom_field => field)
              x.instance_variable_set("@value", cv.value)
            end
            x.value_was = x.value.dup if x.value
            x
          end
        end

        def visible_custom_field_values
          custom_field_values.select(&:visible?)
        end

        def custom_field_values_changed?
          @custom_field_values_changed == true
        end

        # Should the default custom field value be set for the given custom_value?
        # By default, default custom field value is set for new objects only
        def set_custom_field_default?(custom_value)
          new_record?
        end

        def custom_value_for(c)
          field_id = (c.is_a?(CustomField) ? c.id : c.to_i)
          custom_values.detect {|v| v.custom_field_id == field_id }
        end

        def custom_field_value(c)
          field_id = (c.is_a?(CustomField) ? c.id : c.to_i)
          custom_field_values.detect {|v| v.custom_field_id == field_id }.try(:value)
        end

        def validate_custom_field_values
          if new_record? || custom_field_values_changed?
            custom_field_values.each(&:validate_value)
          end
        end

        def save_custom_field_values
          target_custom_values = []
          custom_field_values.each do |custom_field_value|
            if custom_field_value.value.is_a?(Array)
              custom_field_value.value.each do |v|
                target = custom_values.detect {|cv| cv.custom_field == custom_field_value.custom_field && cv.value == v}
                target ||= custom_values.build(:customized => self, :custom_field => custom_field_value.custom_field, :value => v)
                target_custom_values << target
              end
            else
              target = custom_values.detect {|cv| cv.custom_field == custom_field_value.custom_field}
              target ||= custom_values.build(:customized => self, :custom_field => custom_field_value.custom_field)
              target.value = custom_field_value.value
              target_custom_values << target
            end
          end
          self.custom_values = target_custom_values
          custom_values.each(&:save)
          touch if !saved_changes? && custom_values.any?(&:saved_changes?)
          @custom_field_values_changed = false
          true
        end

        def reassign_custom_field_values
          if @custom_field_values
            values = @custom_field_values.inject({}) {|h,v| h[v.custom_field_id] = v.value; h}
            @custom_field_values = nil
            self.custom_field_values = values
          end
        end

        def reset_custom_values!
          @custom_field_values = nil
          @custom_field_values_changed = true
        end

        def reload(*args)
          @custom_field_values = nil
          @custom_field_values_changed = false
          super
        end

        def store_attachment_custom_value_ids
          @attachment_custom_value_ids =
            custom_values.select {|cv| cv.custom_field.field_format == 'attachment'}
                         .map(&:id)
        end

        def destroy_custom_value_attachments
          Attachment.where(:container_id => @attachment_custom_value_ids, :container_type => 'CustomValue')
                    .destroy_all
        end

        module ClassMethods
        end
      end
    end
  end
end
