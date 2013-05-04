# encoding: utf-8
#
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

module CustomFieldsHelper

  def custom_fields_tabs
    CustomField::CUSTOM_FIELDS_TABS
  end

  # Return custom field html tag corresponding to its format
  def custom_field_tag(name, custom_value)
    custom_field = custom_value.custom_field
    field_name = "#{name}[custom_field_values][#{custom_field.id}]"
    field_name << "[]" if custom_field.multiple?
    field_id = "#{name}_custom_field_values_#{custom_field.id}"

    tag_options = {:id => field_id, :class => "#{custom_field.field_format}_cf"}

    field_format = Redmine::CustomFieldFormat.find_by_name(custom_field.field_format)
    case field_format.try(:edit_as)
    when "date"
      text_field_tag(field_name, custom_value.value, tag_options.merge(:size => 10)) +
      calendar_for(field_id)
    when "text"
      text_area_tag(field_name, custom_value.value, tag_options.merge(:rows => 3))
    when "bool"
      hidden_field_tag(field_name, '0') + check_box_tag(field_name, '1', custom_value.true?, tag_options)
    when "list"
      blank_option = ''.html_safe
      unless custom_field.multiple?
        if custom_field.is_required?
          unless custom_field.default_value.present?
            blank_option = content_tag('option', "--- #{l(:actionview_instancetag_blank_option)} ---", :value => '')
          end
        else
          blank_option = content_tag('option')
        end
      end
      s = select_tag(field_name, blank_option + options_for_select(custom_field.possible_values_options(custom_value.customized), custom_value.value),
        tag_options.merge(:multiple => custom_field.multiple?))
      if custom_field.multiple?
        s << hidden_field_tag(field_name, '')
      end
      s
    else
      text_field_tag(field_name, custom_value.value, tag_options)
    end
  end

  # Return custom field label tag
  def custom_field_label_tag(name, custom_value, options={})
    required = options[:required] || custom_value.custom_field.is_required?

    content_tag "label", h(custom_value.custom_field.name) +
      (required ? " <span class=\"required\">*</span>".html_safe : ""),
      :for => "#{name}_custom_field_values_#{custom_value.custom_field.id}"
  end

  # Return custom field tag with its label tag
  def custom_field_tag_with_label(name, custom_value, options={})
    custom_field_label_tag(name, custom_value, options) + custom_field_tag(name, custom_value)
  end

  def custom_field_tag_for_bulk_edit(name, custom_field, projects=nil, value='')
    field_name = "#{name}[custom_field_values][#{custom_field.id}]"
    field_name << "[]" if custom_field.multiple?
    field_id = "#{name}_custom_field_values_#{custom_field.id}"

    tag_options = {:id => field_id, :class => "#{custom_field.field_format}_cf"}

    field_format = Redmine::CustomFieldFormat.find_by_name(custom_field.field_format)
    case field_format.try(:edit_as)
      when "date"
        text_field_tag(field_name, value, tag_options.merge(:size => 10)) +
        calendar_for(field_id)
      when "text"
        text_area_tag(field_name, value, tag_options.merge(:rows => 3))
      when "bool"
        select_tag(field_name, options_for_select([[l(:label_no_change_option), ''],
                                                   [l(:general_text_yes), '1'],
                                                   [l(:general_text_no), '0']], value), tag_options)
      when "list"
        options = []
        options << [l(:label_no_change_option), ''] unless custom_field.multiple?
        options << [l(:label_none), '__none__'] unless custom_field.is_required?
        options += custom_field.possible_values_options(projects)
        select_tag(field_name, options_for_select(options, value), tag_options.merge(:multiple => custom_field.multiple?))
      else
        text_field_tag(field_name, value, tag_options)
    end
  end

  # Return a string used to display a custom value
  def show_value(custom_value)
    return "" unless custom_value
    format_value(custom_value.value, custom_value.custom_field.field_format)
  end

  # Return a string used to display a custom value
  def format_value(value, field_format)
    if value.is_a?(Array)
      value.collect {|v| format_value(v, field_format)}.compact.sort.join(', ')
    else
      Redmine::CustomFieldFormat.format_value(value, field_format)
    end
  end

  # Return an array of custom field formats which can be used in select_tag
  def custom_field_formats_for_select(custom_field)
    Redmine::CustomFieldFormat.as_select(custom_field.class.customized_class.name)
  end

  # Renders the custom_values in api views
  def render_api_custom_values(custom_values, api)
    api.array :custom_fields do
      custom_values.each do |custom_value|
        attrs = {:id => custom_value.custom_field_id, :name => custom_value.custom_field.name}
        attrs.merge!(:multiple => true) if custom_value.custom_field.multiple?
        api.custom_field attrs do
          if custom_value.value.is_a?(Array)
            api.array :value do
              custom_value.value.each do |value|
                api.value value unless value.blank?
              end
            end
          else
            api.value custom_value.value
          end
        end
      end
    end unless custom_values.empty?
  end
end
