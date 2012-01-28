# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
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
          has_many :custom_values, :as => :customized,
                                   :include => :custom_field,
                                   :order => "#{CustomField.table_name}.position",
                                   :dependent => :delete_all,
                                   :validate => false
          send :include, Redmine::Acts::Customizable::InstanceMethods
          validate :validate_custom_field_values
          after_save :save_custom_field_values
        end
      end

      module InstanceMethods
        def self.included(base)
          base.extend ClassMethods
        end
        
        def available_custom_fields
          CustomField.find(:all, :conditions => "type = '#{self.class.name}CustomField'",
                                 :order => 'position')
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
              value = values[key]
              custom_field_value.value = value
            end
          end
          @custom_field_values_changed = true
        end
        
        def custom_field_values
          @custom_field_values ||= available_custom_fields.collect do |field|
            x = CustomFieldValue.new
            x.custom_field = field
            x.customized = self
            cv = custom_values.detect { |v| v.custom_field == field }
            cv ||= custom_values.build(:customized => self, :custom_field => field, :value => nil)
            x.value = cv.value
            x
          end
        end
        
        def visible_custom_field_values
          custom_field_values.select(&:visible?)
        end
        
        def custom_field_values_changed?
          @custom_field_values_changed == true
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
            target = custom_values.detect {|cv| cv.custom_field == custom_field_value.custom_field}
            target ||= custom_values.build(:customized => self, :custom_field => custom_field_value.custom_field)
            target.value = custom_field_value.value
            target_custom_values << target
          end
          self.custom_values = target_custom_values
          custom_values.each(&:save)
          @custom_field_values_changed = false
          true
        end
        
        def reset_custom_values!
          @custom_field_values = nil
          @custom_field_values_changed = true
        end
        
        module ClassMethods
        end
      end
    end
  end
end
