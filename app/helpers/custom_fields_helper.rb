# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2014  Jean-Philippe Lang
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

  CUSTOM_FIELDS_TABS = [
    {:name => 'IssueCustomField', :partial => 'custom_fields/index',
     :label => :label_issue_plural},
    {:name => 'TimeEntryCustomField', :partial => 'custom_fields/index',
     :label => :label_spent_time},
    {:name => 'ProjectCustomField', :partial => 'custom_fields/index',
     :label => :label_project_plural},
    {:name => 'VersionCustomField', :partial => 'custom_fields/index',
     :label => :label_version_plural},
    {:name => 'UserCustomField', :partial => 'custom_fields/index',
     :label => :label_user_plural},
    {:name => 'GroupCustomField', :partial => 'custom_fields/index',
     :label => :label_group_plural},
    {:name => 'TimeEntryActivityCustomField', :partial => 'custom_fields/index',
     :label => TimeEntryActivity::OptionName},
    {:name => 'IssuePriorityCustomField', :partial => 'custom_fields/index',
     :label => IssuePriority::OptionName},
    {:name => 'DocumentCategoryCustomField', :partial => 'custom_fields/index',
     :label => DocumentCategory::OptionName}
  ]

  def render_custom_fields_tabs(types)
    tabs = CUSTOM_FIELDS_TABS.select {|h| types.include?(h[:name]) }
    render_tabs tabs
  end

  def custom_field_type_options
    CUSTOM_FIELDS_TABS.map {|h| [l(h[:label]), h[:name]]}
  end

  def render_custom_field_format_partial(form, custom_field)
    partial = custom_field.format.form_partial
    if partial
      render :partial => custom_field.format.form_partial, :locals => {:f => form, :custom_field => custom_field}
    end
  end

  def custom_field_tag_name(prefix, custom_field)
    name = "#{prefix}[custom_field_values][#{custom_field.id}]"
    name << "[]" if custom_field.multiple?
    name
  end

  def custom_field_tag_id(prefix, custom_field)
    "#{prefix}_custom_field_values_#{custom_field.id}"
  end

  # Return custom field html tag corresponding to its format
  def custom_field_tag(prefix, custom_value, options={})
    custom_value.custom_field.format.edit_tag self,
      custom_field_tag_id(prefix, custom_value.custom_field),
      custom_field_tag_name(prefix, custom_value.custom_field),
      custom_value,
      :class => "#{custom_value.custom_field.field_format}_cf form-control #{options[:classes]}"
  end

  # Return custom field label tag
  def custom_field_label_tag(name, custom_value, options={})
    required = options[:required] || custom_value.custom_field.is_required?
    title = custom_value.custom_field.description.presence
    content = content_tag 'span', custom_value.custom_field.name, :title => title

    content_tag "label", content +
      (required ? " <span class=\"required\">*</span>".html_safe : ""),
      :class => "control-label col-sm-2",
      :for => "#{name}_custom_field_values_#{custom_value.custom_field.id}"
  end

  # Return custom field tag with its label tag
  def custom_field_tag_with_label(name, custom_value, options={})
    custom_field_label_tag(name, custom_value, options) + ("<div class='control-label col-sm-3'>" + custom_field_tag(name, custom_value, options) + "</div>").html_safe()
  end

  def custom_field_tag_for_bulk_edit(name, custom_field, projects=nil, value='')
    field_name = "#{name}[custom_field_values][#{custom_field.id}]"
    field_name << "[]" if custom_field.multiple?
    field_id = "#{name}_custom_field_values_#{custom_field.id}"

    tag_options = {:id => field_id, :class => "#{custom_field.field_format}_cf"}

    unset_tag = ''
    unless custom_field.is_required?
      unset_tag = content_tag('label',
        check_box_tag(field_name, '__none__', (value == '__none__'), :id => nil, :data => {:disables => "##{field_id}"}) + l(:button_clear),
        :class => 'inline'
      )
    end

    field_format = Redmine::CustomFieldFormat.find_by_name(custom_field.field_format)
    case field_format.try(:edit_as)
      when "date"
        text_field_tag(field_name, value, tag_options.merge(:size => 10)) +
        calendar_for(field_id) +
        unset_tag
      when "text"
        text_area_tag(field_name, value, tag_options.merge(:rows => 3)) +
        '<br />'.html_safe +
        unset_tag
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
        text_field_tag(field_name, value, tag_options) +
        unset_tag
    end
  end

  # Return a string used to display a custom value
  def show_value(custom_value, html=true)
    format_object(custom_value, html)
  end

  # Return a string (url format) used to display a custom value
  def show_http_value(custom_value)
    addHttpURL(format_object(custom_value))
  end
  
  # Check if url begins with http and add if necessary
  def addHttpURL(url)
    if (url.starts_with?"http") == false
      return "http://" + url
    end  
      
    return url
  end  

  # Return a string used to display a custom value
  def format_value(value, custom_field)
    format_object(custom_field.format.formatted_value(self, custom_field, value, false), false)
  end

  # Return an array of custom field formats which can be used in select_tag
  def custom_field_formats_for_select(custom_field)
    Redmine::FieldFormat.as_select(custom_field.class.customized_class.name)
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

  def edit_tag_style_tag(form)
    form.select :edit_tag_style, [[l(:label_drop_down_list), ''], [l(:label_checkboxes), 'check_box']], :label => :label_display
  end
end
