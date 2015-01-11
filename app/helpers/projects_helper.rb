# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

module ProjectsHelper
  def project_settings_tabs
    tabs = [{:name => 'info', :action => :edit_project, :partial => 'projects/edit', :label => :label_information_plural},
            {:name => 'modules', :action => :select_project_modules, :partial => 'projects/settings/modules', :label => :label_module_plural},
            {:name => 'members', :action => :manage_members, :partial => 'projects/settings/members', :label => :label_member_plural},
            {:name => 'versions', :action => :manage_versions, :partial => 'projects/settings/versions', :label => :label_version_plural},
            {:name => 'categories', :action => :manage_categories, :partial => 'projects/settings/issue_categories', :label => :label_issue_category_plural},
            {:name => 'wiki', :action => :manage_wiki, :partial => 'projects/settings/wiki', :label => :label_wiki},
            {:name => 'repositories', :action => :manage_repository, :partial => 'projects/settings/repositories', :label => :label_repository_plural},
            {:name => 'boards', :action => :manage_boards, :partial => 'projects/settings/boards', :label => :label_board_plural},
            {:name => 'activities', :action => :manage_project_activities, :partial => 'projects/settings/activities', :label => :enumeration_activities}
            ]
    tabs.select {|tab| User.current.allowed_to?(tab[:action], @project)}
  end

  def parent_project_select_tag(project)
    selected = project.parent
    # retrieve the requested parent project
    parent_id = (params[:project] && params[:project][:parent_id]) || params[:parent_id]
    if parent_id
      selected = (parent_id.blank? ? nil : Project.find(parent_id))
    end

    options = ''
    options << "<option value=''>&nbsp;</option>" if project.allowed_parents.include?(nil)
    options << project_tree_options_for_select(project.allowed_parents.compact, :selected => selected)
    content_tag('select', options.html_safe, :name => 'project[parent_id]', :id => 'project_parent_id')
  end

  def render_project_action_links
    links = []
    if User.current.allowed_to?(:add_project, nil, :global => true)
      links << link_to(l(:label_project_new), new_project_path, :class => 'icon icon-add')
    end
    if User.current.allowed_to?(:view_issues, nil, :global => true)
      links << link_to(l(:label_issue_view_all), issues_path)
    end
    if User.current.allowed_to?(:view_time_entries, nil, :global => true)
      links << link_to(l(:label_overall_spent_time), time_entries_path)
    end
    links << link_to(l(:label_overall_activity), activity_path)
    links.join(" | ").html_safe
  end

  # Renders the projects index
  def render_project_hierarchy(projects)
    render_project_nested_lists(projects) do |project|
      s = link_to_project(project, {}, :class => "#{project.css_classes} #{User.current.member_of?(project) ? 'my-project' : nil}")
      if project.description.present?
        s << content_tag('div', textilizable(project.short_description, :project => project), :class => 'wiki description')
      end
      s
    end
  end

  # Returns a set of options for a select field, grouped by project.
  def version_options_for_select(versions, selected=nil)
    grouped = Hash.new {|h,k| h[k] = []}
    versions.each do |version|
      grouped[version.project.name] << [version.name, version.id]
    end

    selected = selected.is_a?(Version) ? selected.id : selected
    if grouped.keys.size > 1
      grouped_options_for_select(grouped, selected)
    else
      options_for_select((grouped.values.first || []), selected)
    end
  end

  def format_version_sharing(sharing)
    sharing = 'none' unless Version::VERSION_SHARINGS.include?(sharing)
    l("label_version_sharing_#{sharing}")
  end

  def render_api_includes(project, api)
    api.array :trackers do
      project.trackers.each do |tracker|
        api.tracker(:id => tracker.id, :name => tracker.name)
      end
    end if include_in_api_response?('trackers')

    api.array :issue_categories do
      project.issue_categories.each do |category|
        api.issue_category(:id => category.id, :name => category.name)
      end
    end if include_in_api_response?('issue_categories')

    api.array :enabled_modules do
      project.enabled_modules.each do |enabled_module|
        api.enabled_module(:id => enabled_module.id, :name => enabled_module.name)
      end
    end if include_in_api_response?('enabled_modules')

  end
end
