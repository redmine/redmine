# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

require 'action_view/helpers/form_helper'

class Redmine::Views::LabelledFormBuilder < ActionView::Helpers::FormBuilder
  include Redmine::I18n

  (field_helpers.map(&:to_s) - %w(radio_button hidden_field fields_for check_box label) +
        %w(date_select)).each do |selector|
    src = <<-END_SRC
    def #{selector}(field, options = {})
      label_for_field(field, options) + super(field, options.except(:label)).html_safe
    end
    END_SRC
    class_eval src, __FILE__, __LINE__
  end

  def check_box(field, options={}, checked_value="1", unchecked_value="0")
    label_for_field(field, options) + super(field, options.except(:label), checked_value, unchecked_value).html_safe
  end

  def select(field, choices, options = {}, html_options = {})
    label_for_field(field, options) + super(field, choices, options, html_options.except(:label)).html_safe
  end

  def time_zone_select(field, priority_zones = nil, options = {}, html_options = {})
    label_for_field(field, options) + super(field, priority_zones, options, html_options.except(:label)).html_safe
  end

  # A field for entering hours value
  def hours_field(field, options={})
    # display the value before type cast when the entered value is not valid
    if @object.errors[field].blank?
      options = options.merge(:value => format_hours(@object.send field))
    end
    text_field field, options
  end

  # Returns a label tag for the given field
  def label_for_field(field, options = {})
    return ''.html_safe if options.delete(:no_label)
    text = options[:label].is_a?(Symbol) ? l(options[:label]) : options[:label]
    text ||= @object.class.human_attribute_name(field)
    text += @template.content_tag("span", " *", :class => "required") if options.delete(:required)
    @template.content_tag("label", text.html_safe,
                                   :class => (@object && @object.errors[field].present? ? "error" : nil),
                                   :for => (@object_name.to_s + "_" + field.to_s))
  end
end
