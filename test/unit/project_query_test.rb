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

require_relative '../test_helper'

class ProjectQueryTest < ActiveSupport::TestCase
  fixtures :projects, :users,
           :members, :roles, :member_roles,
           :issue_categories, :enumerations,
           :groups_users,
           :enabled_modules,
           :custom_fields, :custom_values,
           :queries,
           :issues, :journals, :journal_details

  include Redmine::I18n

  def test_filter_values_be_arrays
    q = ProjectQuery.new
    assert_nil q.project

    q.available_filters.each do |name, filter|
      values = filter.values
      assert (values.nil? || values.is_a?(Array)),
             "#values for #{name} filter returned a #{values.class.name}"
    end
  end

  def test_project_statuses_filter_should_return_project_statuses
    set_language_if_valid 'en'
    query = ProjectQuery.new(:name => '_')
    query.filters = {'status' => {:operator => '=', :values => []}}
    values = query.available_filters['status'][:values]
    assert_equal ['active', 'closed'], values.map(&:first)
    assert_equal ['1', '5'], values.map(&:second)
  end

  def test_default_columns
    q = ProjectQuery.new
    assert q.columns.any?
    assert q.inline_columns.any?
    assert q.block_columns.empty?
  end

  def test_available_columns_should_include_project_custom_fields
    query = ProjectQuery.new
    assert_include :cf_3, query.available_columns.map(&:name)
  end

  def test_available_display_types_should_returns_bord_and_list
    query = ProjectQuery.new
    query.admin_projects = nil
    assert_equal ['board', 'list'], query.available_display_types
  end

  def test_available_display_types_should_always_returns_list_when_admin_projects_is_set
    query = ProjectQuery.new
    query.admin_projects = 1
    assert_equal ['list'], query.available_display_types
  end

  def test_display_type_default_should_equal_with_setting_project_list_display_type
    ProjectQuery.new.available_display_types.each do |t|
      with_settings :project_list_display_type => t do
        q = ProjectQuery.new
        assert_equal t, q.display_type
      end
    end
  end

  def test_should_determine_default_project_query
    user = User.find(1)
    query = ProjectQuery.find(11)
    user_query = ProjectQuery.find(12)
    user_query.update(visibility: Query::VISIBILITY_PUBLIC)

    [nil, user, User.anonymous].each do |u|
      assert_nil IssueQuery.default(user: u)
    end

    # only global default is set
    with_settings :default_project_query => query.id do
      [nil, user, User.anonymous].each do |u|
        assert_equal query, ProjectQuery.default(user: u)
      end
    end

    # user default, overrides global default
    user.pref.default_project_query = user_query.id
    user.pref.save

    with_settings :default_project_query => query.id do
      assert_equal user_query, ProjectQuery.default(user: user)
    end
  end

  def test_project_query_default_should_return_nil_if_default_query_destroyed
    query = ProjectQuery.find(11)

    Setting.default_project_query = query.id
    query.destroy

    assert_nil ProjectQuery.default
  end

  def test_display_type_should_returns_list_when_admin_projects_is_set
    q = ProjectQuery.new
    q.admin_projects = 1
    assert_equal 'list', q.display_type
  end

  def test_project_statuses_values_should_equal_ancestors_return
    ancestor = Query.new
    q = ProjectQuery.new
    assert_equal ancestor.project_statuses_values, q.project_statuses_values
  end

  def test_project_statuses_values_should_includes_project_status_archeved_when_admin_projects_is_set
    q = ProjectQuery.new
    q.admin_projects = 1
    assert_includes q.project_statuses_values, [l(:project_status_archived), Project::STATUS_ARCHIVED.to_s]
    Query.new.project_statuses_values.each do |status|
      assert_includes q.project_statuses_values, status
    end
  end

  def test_base_scope_should_return_visible_projects
    q = ProjectQuery.new
    assert_equal Project.visible, q.base_scope
  end

  def test_base_scope_should_return_all_projects_when_admin_projects_is_set
    q = ProjectQuery.new
    q.admin_projects = 1
    assert_equal Project.all, q.base_scope
  end

  def test_results_scope_has_last_activity_date
    q = ProjectQuery.generate!(column_names: [:last_activity_date])
    result_projects = q.results_scope({})

    assert_kind_of ActiveRecord::Relation, result_projects
    assert_equal Project, result_projects.klass

    last_activitiy_date = result_projects.find{|p| p.id == 1}.instance_variable_get(:@last_activity_date)
    assert_not_nil last_activitiy_date
    assert_equal Redmine::Activity::Fetcher.new(User.current).events(nil, nil, :project => Project.find(1)).first.updated_on, last_activitiy_date
  end

  def test_results_scope_with_offset_and_limit
    q = ProjectQuery.new

    ((q.results_scope.count / 2) + 1).times do |i|
      limit = 2
      offset = i * 2

      scope_without = q.results_scope.offset(offset).limit(limit).ids
      scope_with = q.results_scope(:offset => offset, :limit => limit).ids

      assert_equal scope_without, scope_with
    end
  end
end
