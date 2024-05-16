## SNIP - Filters
$mc_filters = {}
$mc_filters['assignee'] = {
  :type => 'lookup',
  :label => 'field_assigned_to',
  :db_field => 'issues.assigned_to_id',
  :db_field_holiday => 'holidays.user_id',
  :lookup_id => 'id',
  :operators => [:contains, :not_contains],
  :lookup_value => 'name',
  :lookup_query_model => 'Holiday',
  :lookup_query_method => 'get_activated_users',
  :lookup_query_order => nil,
  :condition => nil,
  :condition_holiday => nil
}
$mc_filters['assignee_group'] = {
  :type => 'lookup',
  :label => 'label_group',
  :db_field => 'issues.assigned_to_id',
  :db_field_holiday => 'holidays.user_id',
  :lookup_id => 'id',
  :operators => [:contains, :not_contains],
  :lookup_value => 'lastname',
  :lookup_query_model => 'Holiday',
  :lookup_query_method => 'get_activated_groups',
  :lookup_query_order => nil,
  :condition => '##FIELD_ID## IN (SELECT user_id FROM groups_users WHERE group_id ##OPERATOR## (?)) OR ##FIELD_ID## ##OPERATOR## (?)',
  :condition_holiday => '##FIELD_ID## IN (SELECT user_id FROM groups_users WHERE group_id ##OPERATOR## (?))'
}
$mc_filters['status'] = {
  :type => 'lookup',
  :label => 'label_issue_status',
  :db_field => 'issues.status_id',
  :lookup_id => 'id',
  :operators => [:contains, :not_contains],
  :lookup_value => 'name',
  :lookup_query_model => 'IssueStatus',
  :lookup_query_method => 'all',
  :lookup_query_order => "issue_statuses.name ASC",
  :condition => nil,
  :condition_holiday => nil
}
$mc_filters['project'] = {
  :type => 'lookup',
  :label => 'label_project',
  :db_field => 'issues.project_id',
  :lookup_id => 'id',
  :operators => [:contains, :not_contains],
  :lookup_value => 'name',
  :lookup_query_model => 'Project',
  :lookup_query_method => 'all',
  :lookup_query_order => "projects.name ASC",
  :condition => nil,
  :condition_holiday => nil
}
$mc_filters['tracker'] = {
  :type => 'lookup',
  :label => 'label_tracker',
  :db_field => 'issues.tracker_id',
  :lookup_id => 'id',
  :operators => [:contains, :not_contains],
  :lookup_value => 'name',
  :lookup_query_model => 'Tracker',
  :lookup_query_method => 'all',
  :lookup_query_order => "trackers.name ASC",
  :condition => nil,
  :condition_holiday => nil
}
$mc_filters['priority'] = {
  :type => 'lookup',
  :label => 'field_priority',
  :db_field => 'issues.priority_id',
  :lookup_id => 'id',
  :operators => [:contains, :not_contains],
  :lookup_value => 'name',
  :lookup_query_model => 'IssuePriority',
  :lookup_query_method => 'all',
  :lookup_query_order => nil,
  :condition => nil,
  :condition_holiday => nil
}
$mc_filters['version'] = {
  :type => 'lookup',
  :label => 'field_version',
  :db_field => 'issues.fixed_version_id',
  :lookup_id => 'id',
  :operators => [:contains, :not_contains],
  :lookup_value => 'name',
  :lookup_query_model => 'Version',
  :lookup_query_method => 'all',
  :lookup_query_order => "versions.name ASC",
  :condition => nil,
  :condition_holiday => nil
}
## SNAP - Filters

require 'vpim'
require_dependency Rails.root.join('plugins','mega_calendar','lib','mega_calendar','users_controller_patch')
require_dependency Rails.root.join('plugins','mega_calendar','lib','mega_calendar','issues_controller_patch')

Redmine::Plugin.register :mega_calendar do
  name 'Mega Calendar plugin'
  author 'Andreas Treubert'
  description 'Better calendar for redmine'
  version '1.9.5'
  url 'https://github.com/berti92/mega_calendar'
  author_url 'https://github.com/berti92'
  requires_redmine :version_or_higher => '5.0.0'
  menu(:top_menu, :calendar, { :controller => 'calendar', :action => 'index' }, :caption => :calendar, :if => Proc.new {(!Setting.plugin_mega_calendar['allowed_users'].blank? && Setting.plugin_mega_calendar['allowed_users'].include?(User.current.id.to_s) ? true : false)})
  menu(:top_menu, :holidays, { :controller => 'holidays', :action => 'index' }, :caption => :holidays, :if => Proc.new {(!Setting.plugin_mega_calendar['allowed_users'].blank? && Setting.plugin_mega_calendar['allowed_users'].include?(User.current.id.to_s) ? true : false)})
  settings :default => {'display_empty_dates' => 0, 'displayed_type' => 'users', 'displayed_users' => User.where(["users.login IS NOT NULL AND users.login <> ''"]).collect {|x| x.id.to_s}, 'default_holiday_color' => 'D59235', 'default_event_color' => '4F90FF', 'sub_path' => '/', 'week_start' => '1', 'allowed_users' => User.where(["users.login IS NOT NULL AND users.login <> ''"]).collect {|x| x.id.to_s}}, :partial => 'settings/mega_calendar_settings'
end

UsersController.prepend(MegaCalendar::UsersControllerPatch)
IssuesController.prepend(MegaCalendar::IssuesControllerPatch)
