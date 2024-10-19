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

module ProjectsHelper
  def project_settings_tabs
    tabs =
      [
        {:name => 'info', :action => :edit_project,
         :partial => 'projects/edit', :label => :label_project},
        {:name => 'members', :action => :manage_members,
         :partial => 'projects/settings/members', :label => :label_member_plural},
        {:name => 'issues', :action => :edit_project, :module => :issue_tracking,
         :partial => 'projects/settings/issues', :label => :label_issue_tracking},
        {:name => 'versions', :action => :manage_versions,
         :partial => 'projects/settings/versions', :label => :label_version_plural,
         :url => {:tab => 'versions', :version_status => params[:version_status],
                  :version_name => params[:version_name]}},
        {:name => 'categories', :action => :manage_categories,
         :partial => 'projects/settings/issue_categories',
         :label => :label_issue_category_plural},
        {:name => 'repositories', :action => :manage_repository,
         :partial => 'projects/settings/repositories', :label => :label_repository_plural},
        {:name => 'boards', :action => :manage_boards,
         :partial => 'projects/settings/boards', :label => :label_board_plural},
        {:name => 'activities', :action => :manage_project_activities,
         :partial => 'projects/settings/activities', :label => :label_time_tracking}
      ]
    tabs.
      select {|tab| User.current.allowed_to?(tab[:action], @project)}.
      select {|tab| tab[:module].nil? || @project.module_enabled?(tab[:module])}
  end

  def parent_project_select_tag(project)
    selected = project.parent
    # retrieve the requested parent project
    parent_id = (params[:project] && params[:project][:parent_id]) || params[:parent_id]
    if parent_id
      selected = (parent_id.blank? ? nil : Project.find(parent_id))
    end

    options = +''
    options << "<option value=''>&nbsp;</option>" if project.allowed_parents.include?(nil)
    options << project_tree_options_for_select(project.allowed_parents.compact, :selected => selected)
    content_tag('select', options.html_safe, :name => 'project[parent_id]', :id => 'project_parent_id')
  end

  def render_project_action_links
    links = (+"").html_safe
    if User.current.allowed_to?(:add_project, nil, :global => true)
      links << link_to(sprite_icon('add', l(:label_project_new)), new_project_path, :class => 'icon icon-add')
    end
    if User.current.admin?
      links << link_to(sprite_icon('settings', l(:label_administration)), admin_projects_path, :class => 'icon icon-settings')
    end
    links
  end

  # Renders the projects index
  def render_project_hierarchy(projects)
    bookmarked_project_ids = User.current.bookmarked_project_ids
    render_project_nested_lists(projects) do |project|
      classes = project.css_classes.split
      classes += %w(icon icon-user my-project) if User.current.member_of?(project)
      classes += %w(icon icon-bookmarked-project) if bookmarked_project_ids.include?(project.id)

      s = link_to_project(project, {}, :class => classes.uniq.join(' '))
      s << sprite_icon('user', l(:label_my_projects), icon_only: true) if User.current.member_of?(project)
      s << sprite_icon('bookmarked', l(:label_my_bookmarks), icon_only: true) if bookmarked_project_ids.include?(project.id)
      if project.description.present?
        s << content_tag('div', textilizable(project.short_description, :project => project), :class => 'wiki description')
      end
      s
    end
  end

  # Returns a set of options for a select field, grouped by project.
  def version_options_for_select(versions, selected=nil)
    grouped = Hash.new {|h, k| h[k] = []}
    versions.each do |version|
      grouped[version.project.name] << [version.name, version.id]
    end

    selected = selected.id if selected.is_a?(Version)
    if grouped.keys.size > 1
      grouped_options_for_select(grouped, selected)
    else
      options_for_select((grouped.values.first || []), selected)
    end
  end

  def project_default_version_options(project)
    versions = project.shared_versions.open.to_a
    if project.default_version && !versions.include?(project.default_version)
      versions << project.default_version
    end
    version_options_for_select(versions, project.default_version)
  end

  def project_default_assigned_to_options(project)
    assignable_users = (project.assignable_users.to_a + [project.default_assigned_to]).uniq.compact
    principals_options_for_select(assignable_users, project.default_assigned_to)
  end

  def project_default_issue_query_options(project)
    public_queries = IssueQuery.only_public
    grouped = {
      l('label_default_queries.for_all_projects')    => public_queries.where(project_id: nil).pluck(:name, :id),
      l('label_default_queries.for_current_project') => public_queries.where(project: project).pluck(:name, :id)
    }
    grouped_options_for_select(grouped, project.default_issue_query_id)
  end

  def format_version_sharing(sharing)
    sharing = 'none' unless Version::VERSION_SHARINGS.include?(sharing)
    l("label_version_sharing_#{sharing}")
  end

  def render_boards_tree(boards, parent=nil, level=0, &block)
    selection = boards.select {|b| b.parent == parent}
    return '' if selection.empty?

    s = ''.html_safe
    selection.each do |board|
      node = capture(board, level, &block)
      node << render_boards_tree(boards, board, level+1, &block)
      s << content_tag('div', node)
    end
    content_tag('div', s, :class => 'sort-level')
  end

  def render_api_includes(project, api)
    api.array :trackers do
      project.rolled_up_trackers(false).visible.each do |tracker|
        api.tracker(:id => tracker.id, :name => tracker.name)
      end
    end if include_in_api_response?('trackers')

    api.array :issue_categories do
      project.issue_categories.each do |category|
        api.issue_category(:id => category.id, :name => category.name)
      end
    end if include_in_api_response?('issue_categories')

    api.array :time_entry_activities do
      project.activities.each do |activity|
        api.time_entry_activity(:id => activity.id, :name => activity.name)
      end
    end if include_in_api_response?('time_entry_activities')

    api.array :enabled_modules do
      project.enabled_modules.each do |enabled_module|
        api.enabled_module(:id => enabled_module.id, :name => enabled_module.name)
      end
    end if include_in_api_response?('enabled_modules')

    api.array :issue_custom_fields do
      project.all_issue_custom_fields.each do |custom_field|
        api.custom_field(:id => custom_field.id, :name => custom_field.name)
      end
    end if include_in_api_response?('issue_custom_fields')
  end

  def bookmark_link(project, user = User.current)
    return '' unless user && user.logged?

    @jump_box ||= Redmine::ProjectJumpBox.new user
    bookmarked = @jump_box.bookmark?(project)
    css = +"icon bookmark "

    if bookmarked
      css << "icon-bookmark"
      icon = "bookmark-delete"
      method = "delete"
      text = sprite_icon(icon, l(:button_project_bookmark_delete))
    else
      css << "icon-bookmark-off"
      icon = "bookmark-add"
      method = "post"
      text = sprite_icon(icon, l(:button_project_bookmark))
    end

    url = bookmark_project_path(project)
    link_to text, url, remote: true, method: method, class: css
  end

  def grouped_project_list(projects, query, &)
    ancestors = []
    grouped_query_results(projects, query) do |project, group_name, group_count, group_totals|
      ancestors.pop while ancestors.any? && !project.is_descendant_of?(ancestors.last)
      yield project, ancestors.size, group_name, group_count, group_totals
      ancestors << project unless project.leaf?
    end
  end
end
