# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

require File.expand_path('../../test_helper', __FILE__)

class TimeEntryQueryTest < ActiveSupport::TestCase
  fixtures :issues, :projects, :users,
           :members, :roles, :member_roles,
           :trackers, :issue_statuses,
           :projects_trackers,
           :journals, :journal_details,
           :issue_categories, :enumerations,
           :groups_users,
           :enabled_modules,
           :custom_fields, :custom_fields_trackers, :custom_fields_projects

  def setup
    User.current = nil
  end

  def test_filter_values_without_project_should_be_arrays
    q = TimeEntryQuery.new
    assert_nil q.project

    q.available_filters.each do |name, filter|
      values = filter.values
      assert (values.nil? || values.is_a?(Array)),
             "#values for #{name} filter returned a #{values.class.name}"
    end
  end

  def test_filter_values_with_project_should_be_arrays
    q = TimeEntryQuery.new(:project => Project.find(1))
    assert_not_nil q.project

    q.available_filters.each do |name, filter|
      values = filter.values
      assert (values.nil? || values.is_a?(Array)),
             "#values for #{name} filter returned a #{values.class.name}"
    end
  end

  def test_cross_project_activity_filter_should_propose_non_active_activities
    activity = TimeEntryActivity.create!(:name => 'Disabled', :active => false)
    assert !activity.active?

    query = TimeEntryQuery.new(:name => '_')
    assert options = query.available_filters['activity_id']
    assert values = options[:values]
    assert_include ["Disabled", activity.id.to_s], values
  end

  def test_activity_filter_should_consider_system_and_project_activities
    TimeEntry.delete_all
    system = TimeEntryActivity.create!(:name => 'Foo')
    TimeEntry.generate!(:activity => system, :hours => 1.0)
    override = TimeEntryActivity.create!(:name => 'Foo', :parent_id => system.id, :project_id => 1)
    other = TimeEntryActivity.create!(:name => 'Bar')
    TimeEntry.generate!(:activity => override, :hours => 2.0)
    TimeEntry.generate!(:activity => other, :hours => 4.0)

    with_current_user User.find(2) do
      query = TimeEntryQuery.new(:name => '_')
      query.add_filter('activity_id', '=', [system.id.to_s])
      assert_equal 3.0, query.results_scope.sum(:hours)

      query = TimeEntryQuery.new(:name => '_')
      query.add_filter('activity_id', '!', [system.id.to_s])
      assert_equal 4.0, query.results_scope.sum(:hours)
    end
  end

  def test_project_query_should_include_project_issue_custom_fields_only_as_filters
    global = IssueCustomField.generate!(:is_for_all => true, :is_filter => true)
    field_on_project = IssueCustomField.generate!(:is_for_all => false, :project_ids => [3], :is_filter => true)
    field_not_on_project = IssueCustomField.generate!(:is_for_all => false, :project_ids => [1,2], :is_filter => true)

    query = TimeEntryQuery.new(:project => Project.find(3))

    assert_include "issue.cf_#{global.id}", query.available_filters.keys
    assert_include "issue.cf_#{field_on_project.id}", query.available_filters.keys
    assert_not_include "issue.cf_#{field_not_on_project.id}", query.available_filters.keys
  end

  def test_project_query_should_include_project_issue_custom_fields_only_as_columns
    global = IssueCustomField.generate!(:is_for_all => true, :is_filter => true)
    field_on_project = IssueCustomField.generate!(:is_for_all => false, :project_ids => [3], :is_filter => true)
    field_not_on_project = IssueCustomField.generate!(:is_for_all => false, :project_ids => [1,2], :is_filter => true)

    query = TimeEntryQuery.new(:project => Project.find(3))

    assert_include "issue.cf_#{global.id}", query.available_columns.map(&:name).map(&:to_s)
    assert_include "issue.cf_#{field_on_project.id}", query.available_columns.map(&:name).map(&:to_s)
    assert_not_include "issue.cf_#{field_not_on_project.id}", query.available_columns.map(&:name).map(&:to_s)
  end

  def test_issue_category_filter_should_not_be_available_in_global_queries
    query = TimeEntryQuery.new(:project => nil, :name => '_')
    assert !query.available_filters.has_key?('issue.category_id')
  end

  def test_project_status_filter_should_be_available_in_global_queries
    query = TimeEntryQuery.new(:project => nil, :name => '_')
    assert query.available_filters.has_key?('project.status')
  end

  def test_project_status_filter_should_be_available_when_project_has_subprojects
    query = TimeEntryQuery.new(:project => Project.find(1), :name => '_')
    assert query.available_filters.has_key?('project.status')
  end

  def test_project_status_filter_should_not_be_available_when_project_is_leaf
    query = TimeEntryQuery.new(:project => Project.find(2), :name => '_')
    assert !query.available_filters.has_key?('project.status')
  end

  def test_results_scope_should_be_in_the_same_order_when_paginating
    4.times { TimeEntry.generate! }
    q = TimeEntryQuery.new
    q.sort_criteria = {'0' => ['user', 'asc']}
    time_entry_ids = q.results_scope.pluck(:id)
    paginated_time_entry_ids = []
    # Test with a maximum of 2 records per page.
    ((q.results_scope.count / 2) + 1).times do |i|
      paginated_time_entry_ids += q.results_scope.offset((i * 2)).limit(2).pluck(:id)
    end

    # Non-paginated time entry ids and paginated time entry ids should be in the same order.
    assert_equal time_entry_ids, paginated_time_entry_ids
  end
end
