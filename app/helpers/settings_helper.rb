# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

module SettingsHelper
  def administration_settings_tabs
    tabs =
      [
        {:name => 'general', :partial => 'settings/general', :label => :label_general},
        {:name => 'display', :partial => 'settings/display', :label => :label_display},
        {:name => 'authentication', :partial => 'settings/authentication',
         :label => :label_authentication},
        {:name => 'api', :partial => 'settings/api', :label => :label_api},
        {:name => 'projects', :partial => 'settings/projects', :label => :label_project_plural},
        {:name => 'users', :partial => 'settings/users', :label => :label_user_plural},
        {:name => 'issues', :partial => 'settings/issues', :label => :label_issue_tracking},
        {:name => 'timelog', :partial => 'settings/timelog', :label => :label_time_tracking},
        {:name => 'attachments', :partial => 'settings/attachments',
         :label => :label_attachment_plural},
        {:name => 'notifications', :partial => 'settings/notifications',
         :label => :field_mail_notification},
        {:name => 'mail_handler', :partial => 'settings/mail_handler',
         :label => :label_incoming_emails},
        {:name => 'repositories', :partial => 'settings/repositories',
         :label => :label_repository_plural}
      ]
  end

  def render_settings_error(errors)
    return if errors.blank?

    s = ''.html_safe
    errors.each do |name, message|
      s << content_tag('li', content_tag('b', l("setting_#{name}")) + " " + message)
    end
    content_tag('div', content_tag('ul', s), :id => 'errorExplanation')
  end

  def setting_value(setting)
    value = nil
    if params[:settings]
      value = params[:settings][setting]
    end
    value || Setting.send(setting)
  end

  def setting_select(setting, choices, options={})
    if blank_text = options.delete(:blank)
      choices = [[blank_text.is_a?(Symbol) ? l(blank_text) : blank_text, '']] + choices
    end
    setting_label(setting, options).html_safe +
      select_tag("settings[#{setting}]",
                 options_for_select(choices, setting_value(setting).to_s),
                 options).html_safe
  end

  def setting_multiselect(setting, choices, options={})
    setting_values = setting_value(setting)
    setting_values = [] unless setting_values.is_a?(Array)

    content_tag("label", l(options[:label] || "setting_#{setting}")) +
      hidden_field_tag("settings[#{setting}][]", '').html_safe +
      choices.collect do |choice|
        text, value = (choice.is_a?(Array) ? choice : [choice, choice])
        content_tag(
          'label',
          check_box_tag(
            "settings[#{setting}][]",
            value,
            setting_values.include?(value),
            :id => nil
          ) + text.to_s,
          :class => (options[:inline] ? 'inline' : 'block')
        )
      end.join.html_safe
  end

  def setting_text_field(setting, options={})
    setting_label(setting, options).html_safe +
      text_field_tag("settings[#{setting}]", setting_value(setting), options).html_safe
  end

  def setting_text_area(setting, options={})
    setting_label(setting, options).html_safe +
      text_area_tag("settings[#{setting}]", setting_value(setting), options).html_safe
  end

  def setting_check_box(setting, options={})
    setting_label(setting, options).html_safe +
      hidden_field_tag("settings[#{setting}]", 0, :id => nil).html_safe +
        check_box_tag("settings[#{setting}]", 1, setting_value(setting).to_s != '0', options).html_safe
  end

  def setting_label(setting, options={})
    label = options.delete(:label)
    if label == false
      ''
    else
      text = label.is_a?(String) ? label : l(label || "setting_#{setting}")
      label_tag("settings_#{setting}", text, options[:label_options])
    end
  end

  # Renders a notification field for a Redmine::Notifiable option
  def notification_field(notifiable)
    tag_data =
      if notifiable.parent.present?
        {:parent_notifiable => notifiable.parent}
      else
        {:disables => "input[data-parent-notifiable=#{notifiable.name}]"}
      end
    tag = check_box_tag('settings[notified_events][]',
                        notifiable.name,
                        setting_value('notified_events').include?(notifiable.name),
                        :id => nil,
                        :data => tag_data)
    text = l_or_humanize(notifiable.name, :prefix => 'label_')
    options = {}
    if notifiable.parent.present?
      options[:class] = "parent"
    end
    content_tag(:label, tag + text, options)
  end

  def session_lifetime_options
    options = [[l(:label_disabled), 0]]
    options += [4, 8, 12].map do |hours|
      [l('datetime.distance_in_words.x_hours', :count => hours), (hours * 60).to_s]
    end
    options += [1, 7, 30, 60, 365].map do |days|
      [l('datetime.distance_in_words.x_days', :count => days), (days * 24 * 60).to_s]
    end
    options
  end

  def session_timeout_options
    options = [[l(:label_disabled), 0]]
    options += [1, 2, 4, 8, 12, 24, 48].map do |hours|
      [l('datetime.distance_in_words.x_hours', :count => hours), (hours * 60).to_s]
    end
    options
  end

  def link_copied_issue_options
    options = [
      [:general_text_Yes, 'yes'],
      [:general_text_No, 'no'],
      [:label_ask, 'ask']
    ]

    options.map {|label, value| [l(label), value.to_s]}
  end

  def default_global_issue_query_options
    [[l(:label_none), '']] + IssueQuery.only_public.where(project_id: nil).pluck(:name, :id)
  end

  def default_global_project_query_options
    [[l(:label_none), '']] + ProjectQuery.only_public.pluck(:name, :id)
  end

  def cross_project_subtasks_options
    options = [
      [:label_disabled, ''],
      [:label_cross_project_system, 'system'],
      [:label_cross_project_tree, 'tree'],
      [:label_cross_project_hierarchy, 'hierarchy'],
      [:label_cross_project_descendants, 'descendants']
    ]

    options.map {|label, value| [l(label), value.to_s]}
  end

  def parent_issue_dates_options
    options = [
      [:label_parent_task_attributes_derived, 'derived'],
      [:label_parent_task_attributes_independent, 'independent']
    ]

    options.map {|label, value| [l(label), value.to_s]}
  end

  def parent_issue_priority_options
    options = [
      [:label_parent_task_attributes_derived, 'derived'],
      [:label_parent_task_attributes_independent, 'independent']
    ]

    options.map {|label, value| [l(label), value.to_s]}
  end

  def parent_issue_done_ratio_options
    options = [
      [:label_parent_task_attributes_derived, 'derived'],
      [:label_parent_task_attributes_independent, 'independent']
    ]

    options.map {|label, value| [l(label), value.to_s]}
  end

  # Returns the options for the date_format setting
  def date_format_setting_options(locale)
    Setting::DATE_FORMATS.map do |f|
      today = ::I18n.l(User.current.today, :locale => locale, :format => f)
      format = f.delete('%').gsub(/[dmY]/) do
        {'d' => 'dd', 'm' => 'mm', 'Y' => 'yyyy'}[$&]
      end
      ["#{today} (#{format})", f]
    end
  end

  def gravatar_default_setting_options
    [['Identicons', 'identicon'],
     ['Monster ids', 'monsterid'],
     ['Mystery man', 'mm'],
     ['Retro', 'retro'],
     ['Robohash', 'robohash'],
     ['Wavatars', 'wavatar']]
  end
end
