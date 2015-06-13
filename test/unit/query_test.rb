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

require File.expand_path('../../test_helper', __FILE__)

class QueryTest < ActiveSupport::TestCase
  include Redmine::I18n

  fixtures :projects, :enabled_modules, :users, :members,
           :member_roles, :roles, :trackers, :issue_statuses,
           :issue_categories, :enumerations, :issues,
           :watchers, :custom_fields, :custom_values, :versions,
           :queries,
           :projects_trackers,
           :custom_fields_trackers,
           :workflows

  def setup
    User.current = nil
  end

  def test_query_with_roles_visibility_should_validate_roles
    set_language_if_valid 'en'
    query = IssueQuery.new(:name => 'Query', :visibility => IssueQuery::VISIBILITY_ROLES)
    assert !query.save
    assert_include "Roles cannot be blank", query.errors.full_messages
    query.role_ids = [1, 2]
    assert query.save
  end

  def test_changing_roles_visibility_should_clear_roles
    query = IssueQuery.create!(:name => 'Query', :visibility => IssueQuery::VISIBILITY_ROLES, :role_ids => [1, 2])
    assert_equal 2, query.roles.count

    query.visibility = IssueQuery::VISIBILITY_PUBLIC
    query.save!
    assert_equal 0, query.roles.count
  end

  def test_available_filters_should_be_ordered
    set_language_if_valid 'en'
    query = IssueQuery.new
    assert_equal 0, query.available_filters.keys.index('status_id')
    expected_order = [
      "Status",
      "Project",
      "Tracker",
      "Priority"
    ]
    assert_equal expected_order,
                 (query.available_filters.values.map{|v| v[:name]} & expected_order)
  end

  def test_available_filters_with_custom_fields_should_be_ordered
    set_language_if_valid 'en'
    UserCustomField.create!(
              :name => 'order test', :field_format => 'string',
              :is_for_all => true, :is_filter => true
            )
    query = IssueQuery.new
    expected_order = [
      "Searchable field",
      "Database",
      "Project's Development status",
      "Author's order test",
      "Assignee's order test"
    ]
    assert_equal expected_order,
                 (query.available_filters.values.map{|v| v[:name]} & expected_order)
  end

  def test_custom_fields_for_all_projects_should_be_available_in_global_queries
    query = IssueQuery.new(:project => nil, :name => '_')
    assert query.available_filters.has_key?('cf_1')
    assert !query.available_filters.has_key?('cf_3')
  end

  def test_system_shared_versions_should_be_available_in_global_queries
    Version.find(2).update_attribute :sharing, 'system'
    query = IssueQuery.new(:project => nil, :name => '_')
    assert query.available_filters.has_key?('fixed_version_id')
    assert query.available_filters['fixed_version_id'][:values].detect {|v| v.last == '2'}
  end

  def test_project_filter_in_global_queries
    query = IssueQuery.new(:project => nil, :name => '_')
    project_filter = query.available_filters["project_id"]
    assert_not_nil project_filter
    project_ids = project_filter[:values].map{|p| p[1]}
    assert project_ids.include?("1")  #public project
    assert !project_ids.include?("2") #private project user cannot see
  end

  def test_available_filters_should_not_include_fields_disabled_on_all_trackers
    Tracker.all.each do |tracker|
      tracker.core_fields = Tracker::CORE_FIELDS - ['start_date']
      tracker.save!
    end

    query = IssueQuery.new(:name => '_')
    assert_include 'due_date', query.available_filters
    assert_not_include 'start_date', query.available_filters
  end

  def find_issues_with_query(query)
    Issue.joins(:status, :tracker, :project, :priority).where(
         query.statement
       ).to_a
  end

  def assert_find_issues_with_query_is_successful(query)
    assert_nothing_raised do
      find_issues_with_query(query)
    end
  end

  def assert_query_statement_includes(query, condition)
    assert_include condition, query.statement
  end

  def assert_query_result(expected, query)
    assert_nothing_raised do
      assert_equal expected.map(&:id).sort, query.issues.map(&:id).sort
      assert_equal expected.size, query.issue_count
    end
  end

  def test_query_should_allow_shared_versions_for_a_project_query
    subproject_version = Version.find(4)
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('fixed_version_id', '=', [subproject_version.id.to_s])

    assert query.statement.include?("#{Issue.table_name}.fixed_version_id IN ('4')")
  end

  def test_query_with_multiple_custom_fields
    query = IssueQuery.find(1)
    assert query.valid?
    assert query.statement.include?("#{CustomValue.table_name}.value IN ('MySQL')")
    issues = find_issues_with_query(query)
    assert_equal 1, issues.length
    assert_equal Issue.find(3), issues.first
  end

  def test_operator_none
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('fixed_version_id', '!*', [''])
    query.add_filter('cf_1', '!*', [''])
    assert query.statement.include?("#{Issue.table_name}.fixed_version_id IS NULL")
    assert query.statement.include?("#{CustomValue.table_name}.value IS NULL OR #{CustomValue.table_name}.value = ''")
    find_issues_with_query(query)
  end

  def test_operator_none_for_integer
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('estimated_hours', '!*', [''])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    assert issues.all? {|i| !i.estimated_hours}
  end

  def test_operator_none_for_date
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('start_date', '!*', [''])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    assert issues.all? {|i| i.start_date.nil?}
  end

  def test_operator_none_for_string_custom_field
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('cf_2', '!*', [''])
    assert query.has_filter?('cf_2')
    issues = find_issues_with_query(query)
    assert !issues.empty?
    assert issues.all? {|i| i.custom_field_value(2).blank?}
  end

  def test_operator_all
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('fixed_version_id', '*', [''])
    query.add_filter('cf_1', '*', [''])
    assert query.statement.include?("#{Issue.table_name}.fixed_version_id IS NOT NULL")
    assert query.statement.include?("#{CustomValue.table_name}.value IS NOT NULL AND #{CustomValue.table_name}.value <> ''")
    find_issues_with_query(query)
  end

  def test_operator_all_for_date
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('start_date', '*', [''])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    assert issues.all? {|i| i.start_date.present?}
  end

  def test_operator_all_for_string_custom_field
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('cf_2', '*', [''])
    assert query.has_filter?('cf_2')
    issues = find_issues_with_query(query)
    assert !issues.empty?
    assert issues.all? {|i| i.custom_field_value(2).present?}
  end

  def test_numeric_filter_should_not_accept_non_numeric_values
    query = IssueQuery.new(:name => '_')
    query.add_filter('estimated_hours', '=', ['a'])

    assert query.has_filter?('estimated_hours')
    assert !query.valid?
  end

  def test_operator_is_on_float
    Issue.where(:id => 2).update_all("estimated_hours = 171.2")
    query = IssueQuery.new(:name => '_')
    query.add_filter('estimated_hours', '=', ['171.20'])
    issues = find_issues_with_query(query)
    assert_equal 1, issues.size
    assert_equal 2, issues.first.id
  end

  def test_operator_is_on_integer_custom_field
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'int', :is_for_all => true, :is_filter => true, :trackers => Tracker.all)
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => '7')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(2), :value => '12')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(3), :value => '')

    query = IssueQuery.new(:name => '_')
    query.add_filter("cf_#{f.id}", '=', ['12'])
    issues = find_issues_with_query(query)
    assert_equal 1, issues.size
    assert_equal 2, issues.first.id
  end

  def test_operator_is_on_integer_custom_field_should_accept_negative_value
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'int', :is_for_all => true, :is_filter => true, :trackers => Tracker.all)
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => '7')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(2), :value => '-12')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(3), :value => '')

    query = IssueQuery.new(:name => '_')
    query.add_filter("cf_#{f.id}", '=', ['-12'])
    assert query.valid?
    issues = find_issues_with_query(query)
    assert_equal 1, issues.size
    assert_equal 2, issues.first.id
  end

  def test_operator_is_on_float_custom_field
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'float', :is_filter => true, :is_for_all => true, :trackers => Tracker.all)
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => '7.3')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(2), :value => '12.7')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(3), :value => '')

    query = IssueQuery.new(:name => '_')
    query.add_filter("cf_#{f.id}", '=', ['12.7'])
    issues = find_issues_with_query(query)
    assert_equal 1, issues.size
    assert_equal 2, issues.first.id
  end

  def test_operator_is_on_float_custom_field_should_accept_negative_value
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'float', :is_filter => true, :is_for_all => true, :trackers => Tracker.all)
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => '7.3')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(2), :value => '-12.7')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(3), :value => '')

    query = IssueQuery.new(:name => '_')
    query.add_filter("cf_#{f.id}", '=', ['-12.7'])
    assert query.valid?
    issues = find_issues_with_query(query)
    assert_equal 1, issues.size
    assert_equal 2, issues.first.id
  end

  def test_operator_is_on_multi_list_custom_field
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'list', :is_filter => true, :is_for_all => true,
      :possible_values => ['value1', 'value2', 'value3'], :multiple => true, :trackers => Tracker.all)
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => 'value1')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => 'value2')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(3), :value => 'value1')

    query = IssueQuery.new(:name => '_')
    query.add_filter("cf_#{f.id}", '=', ['value1'])
    issues = find_issues_with_query(query)
    assert_equal [1, 3], issues.map(&:id).sort

    query = IssueQuery.new(:name => '_')
    query.add_filter("cf_#{f.id}", '=', ['value2'])
    issues = find_issues_with_query(query)
    assert_equal [1], issues.map(&:id).sort
  end

  def test_operator_is_not_on_multi_list_custom_field
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'list', :is_filter => true, :is_for_all => true,
      :possible_values => ['value1', 'value2', 'value3'], :multiple => true, :trackers => Tracker.all)
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => 'value1')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => 'value2')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(3), :value => 'value1')

    query = IssueQuery.new(:name => '_')
    query.add_filter("cf_#{f.id}", '!', ['value1'])
    issues = find_issues_with_query(query)
    assert !issues.map(&:id).include?(1)
    assert !issues.map(&:id).include?(3)

    query = IssueQuery.new(:name => '_')
    query.add_filter("cf_#{f.id}", '!', ['value2'])
    issues = find_issues_with_query(query)
    assert !issues.map(&:id).include?(1)
    assert issues.map(&:id).include?(3)
  end

  def test_operator_is_on_is_private_field
    # is_private filter only available for those who can set issues private
    User.current = User.find(2)

    query = IssueQuery.new(:name => '_')
    assert query.available_filters.key?('is_private')

    query.add_filter("is_private", '=', ['1'])
    issues = find_issues_with_query(query)
    assert issues.any?
    assert_nil issues.detect {|issue| !issue.is_private?}
  ensure
    User.current = nil
  end

  def test_operator_is_not_on_is_private_field
    # is_private filter only available for those who can set issues private
    User.current = User.find(2)

    query = IssueQuery.new(:name => '_')
    assert query.available_filters.key?('is_private')

    query.add_filter("is_private", '!', ['1'])
    issues = find_issues_with_query(query)
    assert issues.any?
    assert_nil issues.detect {|issue| issue.is_private?}
  ensure
    User.current = nil
  end

  def test_operator_greater_than
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('done_ratio', '>=', ['40'])
    assert query.statement.include?("#{Issue.table_name}.done_ratio >= 40.0")
    find_issues_with_query(query)
  end

  def test_operator_greater_than_a_float
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('estimated_hours', '>=', ['40.5'])
    assert query.statement.include?("#{Issue.table_name}.estimated_hours >= 40.5")
    find_issues_with_query(query)
  end

  def test_operator_greater_than_on_int_custom_field
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'int', :is_filter => true, :is_for_all => true, :trackers => Tracker.all)
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => '7')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(2), :value => '12')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(3), :value => '')

    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter("cf_#{f.id}", '>=', ['8'])
    issues = find_issues_with_query(query)
    assert_equal 1, issues.size
    assert_equal 2, issues.first.id
  end

  def test_operator_lesser_than
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('done_ratio', '<=', ['30'])
    assert query.statement.include?("#{Issue.table_name}.done_ratio <= 30.0")
    find_issues_with_query(query)
  end

  def test_operator_lesser_than_on_custom_field
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'int', :is_filter => true, :is_for_all => true)
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter("cf_#{f.id}", '<=', ['30'])
    assert_match /CAST.+ <= 30\.0/, query.statement
    find_issues_with_query(query)
  end

  def test_operator_lesser_than_on_date_custom_field
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'date', :is_filter => true, :is_for_all => true, :trackers => Tracker.all)
    CustomValue.create!(:custom_field => f, :customized => Issue.find(1), :value => '2013-04-11')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(2), :value => '2013-05-14')
    CustomValue.create!(:custom_field => f, :customized => Issue.find(3), :value => '')

    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter("cf_#{f.id}", '<=', ['2013-05-01'])
    issue_ids = find_issues_with_query(query).map(&:id)
    assert_include 1, issue_ids
    assert_not_include 2, issue_ids
    assert_not_include 3, issue_ids
  end

  def test_operator_between
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('done_ratio', '><', ['30', '40'])
    assert_include "#{Issue.table_name}.done_ratio BETWEEN 30.0 AND 40.0", query.statement
    find_issues_with_query(query)
  end

  def test_operator_between_on_custom_field
    f = IssueCustomField.create!(:name => 'filter', :field_format => 'int', :is_filter => true, :is_for_all => true)
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter("cf_#{f.id}", '><', ['30', '40'])
    assert_match /CAST.+ BETWEEN 30.0 AND 40.0/, query.statement
    find_issues_with_query(query)
  end

  def test_date_filter_should_not_accept_non_date_values
    query = IssueQuery.new(:name => '_')
    query.add_filter('created_on', '=', ['a'])

    assert query.has_filter?('created_on')
    assert !query.valid?
  end

  def test_date_filter_should_not_accept_invalid_date_values
    query = IssueQuery.new(:name => '_')
    query.add_filter('created_on', '=', ['2011-01-34'])

    assert query.has_filter?('created_on')
    assert !query.valid?
  end

  def test_relative_date_filter_should_not_accept_non_integer_values
    query = IssueQuery.new(:name => '_')
    query.add_filter('created_on', '>t-', ['a'])

    assert query.has_filter?('created_on')
    assert !query.valid?
  end

  def test_operator_date_equals
    query = IssueQuery.new(:name => '_')
    query.add_filter('due_date', '=', ['2011-07-10'])
    assert_match /issues\.due_date > '#{quoted_date "2011-07-09"} 23:59:59(\.\d+)?' AND issues\.due_date <= '#{quoted_date "2011-07-10"} 23:59:59(\.\d+)?/,
      query.statement
    find_issues_with_query(query)
  end

  def test_operator_date_lesser_than
    query = IssueQuery.new(:name => '_')
    query.add_filter('due_date', '<=', ['2011-07-10'])
    assert_match /issues\.due_date <= '#{quoted_date "2011-07-10"} 23:59:59(\.\d+)?/, query.statement
    find_issues_with_query(query)
  end

  def test_operator_date_lesser_than_with_timestamp
    query = IssueQuery.new(:name => '_')
    query.add_filter('updated_on', '<=', ['2011-07-10T19:13:52'])
    assert_match /issues\.updated_on <= '#{quoted_date "2011-07-10"} 19:13:52/, query.statement
    find_issues_with_query(query)
  end

  def test_operator_date_greater_than
    query = IssueQuery.new(:name => '_')
    query.add_filter('due_date', '>=', ['2011-07-10'])
    assert_match /issues\.due_date > '#{quoted_date "2011-07-09"} 23:59:59(\.\d+)?'/, query.statement
    find_issues_with_query(query)
  end

  def test_operator_date_greater_than_with_timestamp
    query = IssueQuery.new(:name => '_')
    query.add_filter('updated_on', '>=', ['2011-07-10T19:13:52'])
    assert_match /issues\.updated_on > '#{quoted_date "2011-07-10"} 19:13:51(\.0+)?'/, query.statement
    find_issues_with_query(query)
  end

  def test_operator_date_between
    query = IssueQuery.new(:name => '_')
    query.add_filter('due_date', '><', ['2011-06-23', '2011-07-10'])
    assert_match /issues\.due_date > '#{quoted_date "2011-06-22"} 23:59:59(\.\d+)?' AND issues\.due_date <= '#{quoted_date "2011-07-10"} 23:59:59(\.\d+)?'/,
      query.statement
    find_issues_with_query(query)
  end

  def test_operator_in_more_than
    Issue.find(7).update_attribute(:due_date, (Date.today + 15))
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', '>t+', ['15'])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    issues.each {|issue| assert(issue.due_date >= (Date.today + 15))}
  end

  def test_operator_in_less_than
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', '<t+', ['15'])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    issues.each {|issue| assert(issue.due_date <= (Date.today + 15))}
  end

  def test_operator_in_the_next_days
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', '><t+', ['15'])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    issues.each {|issue| assert(issue.due_date >= Date.today && issue.due_date <= (Date.today + 15))}
  end

  def test_operator_less_than_ago
    Issue.find(7).update_attribute(:due_date, (Date.today - 3))
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', '>t-', ['3'])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    issues.each {|issue| assert(issue.due_date >= (Date.today - 3))}
  end

  def test_operator_in_the_past_days
    Issue.find(7).update_attribute(:due_date, (Date.today - 3))
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', '><t-', ['3'])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    issues.each {|issue| assert(issue.due_date >= (Date.today - 3) && issue.due_date <= Date.today)}
  end

  def test_operator_more_than_ago
    Issue.find(7).update_attribute(:due_date, (Date.today - 10))
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', '<t-', ['10'])
    assert query.statement.include?("#{Issue.table_name}.due_date <=")
    issues = find_issues_with_query(query)
    assert !issues.empty?
    issues.each {|issue| assert(issue.due_date <= (Date.today - 10))}
  end

  def test_operator_in
    Issue.find(7).update_attribute(:due_date, (Date.today + 2))
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', 't+', ['2'])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    issues.each {|issue| assert_equal((Date.today + 2), issue.due_date)}
  end

  def test_operator_ago
    Issue.find(7).update_attribute(:due_date, (Date.today - 3))
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', 't-', ['3'])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    issues.each {|issue| assert_equal((Date.today - 3), issue.due_date)}
  end

  def test_operator_today
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', 't', [''])
    issues = find_issues_with_query(query)
    assert !issues.empty?
    issues.each {|issue| assert_equal Date.today, issue.due_date}
  end

  def test_operator_date_periods
    %w(t ld w lw l2w m lm y).each do |operator|
      query = IssueQuery.new(:name => '_')
      query.add_filter('due_date', operator, [''])
      assert query.valid?
      assert query.issues
    end
  end

  def test_operator_datetime_periods
    %w(t ld w lw l2w m lm y).each do |operator|
      query = IssueQuery.new(:name => '_')
      query.add_filter('created_on', operator, [''])
      assert query.valid?
      assert query.issues
    end
  end

  def test_operator_contains
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('subject', '~', ['uNable'])
    assert query.statement.include?("LOWER(#{Issue.table_name}.subject) LIKE '%unable%'")
    result = find_issues_with_query(query)
    assert result.empty?
    result.each {|issue| assert issue.subject.downcase.include?('unable') }
  end

  def test_range_for_this_week_with_week_starting_on_monday
    I18n.locale = :fr
    assert_equal '1', I18n.t(:general_first_day_of_week)

    Date.stubs(:today).returns(Date.parse('2011-04-29'))

    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', 'w', [''])
    assert_match /issues\.due_date > '#{quoted_date "2011-04-24"} 23:59:59(\.\d+)?' AND issues\.due_date <= '#{quoted_date "2011-05-01"} 23:59:59(\.\d+)?/,
      query.statement
    I18n.locale = :en
  end

  def test_range_for_this_week_with_week_starting_on_sunday
    I18n.locale = :en
    assert_equal '7', I18n.t(:general_first_day_of_week)

    Date.stubs(:today).returns(Date.parse('2011-04-29'))

    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('due_date', 'w', [''])
    assert_match /issues\.due_date > '#{quoted_date "2011-04-23"} 23:59:59(\.\d+)?' AND issues\.due_date <= '#{quoted_date "2011-04-30"} 23:59:59(\.\d+)?/,
      query.statement
  end

  def test_operator_does_not_contains
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.add_filter('subject', '!~', ['uNable'])
    assert query.statement.include?("LOWER(#{Issue.table_name}.subject) NOT LIKE '%unable%'")
    find_issues_with_query(query)
  end

  def test_filter_assigned_to_me
    user = User.find(2)
    group = Group.find(10)
    User.current = user
    i1 = Issue.generate!(:project_id => 1, :tracker_id => 1, :assigned_to => user)
    i2 = Issue.generate!(:project_id => 1, :tracker_id => 1, :assigned_to => group)
    i3 = Issue.generate!(:project_id => 1, :tracker_id => 1, :assigned_to => Group.find(11))
    group.users << user

    query = IssueQuery.new(:name => '_', :filters => { 'assigned_to_id' => {:operator => '=', :values => ['me']}})
    result = query.issues
    assert_equal Issue.visible.where(:assigned_to_id => ([2] + user.reload.group_ids)).sort_by(&:id), result.sort_by(&:id)

    assert result.include?(i1)
    assert result.include?(i2)
    assert !result.include?(i3)
  end

  def test_user_custom_field_filtered_on_me
    User.current = User.find(2)
    cf = IssueCustomField.create!(:field_format => 'user', :is_for_all => true, :is_filter => true, :name => 'User custom field', :tracker_ids => [1])
    issue1 = Issue.create!(:project_id => 1, :tracker_id => 1, :custom_field_values => {cf.id.to_s => '2'}, :subject => 'Test', :author_id => 1)
    issue2 = Issue.generate!(:project_id => 1, :tracker_id => 1, :custom_field_values => {cf.id.to_s => '3'})

    query = IssueQuery.new(:name => '_', :project => Project.find(1))
    filter = query.available_filters["cf_#{cf.id}"]
    assert_not_nil filter
    assert_include 'me', filter[:values].map{|v| v[1]}

    query.filters = { "cf_#{cf.id}" => {:operator => '=', :values => ['me']}}
    result = query.issues
    assert_equal 1, result.size
    assert_equal issue1, result.first
  end

  def test_filter_on_me_by_anonymous_user
    User.current = nil
    query = IssueQuery.new(:name => '_', :filters => { 'assigned_to_id' => {:operator => '=', :values => ['me']}})
    assert_equal [], query.issues
  end

  def test_filter_my_projects
    User.current = User.find(2)
    query = IssueQuery.new(:name => '_')
    filter = query.available_filters['project_id']
    assert_not_nil filter
    assert_include 'mine', filter[:values].map{|v| v[1]}

    query.filters = { 'project_id' => {:operator => '=', :values => ['mine']}}
    result = query.issues
    assert_nil result.detect {|issue| !User.current.member_of?(issue.project)}
  end

  def test_filter_watched_issues
    User.current = User.find(1)
    query = IssueQuery.new(:name => '_', :filters => { 'watcher_id' => {:operator => '=', :values => ['me']}})
    result = find_issues_with_query(query)
    assert_not_nil result
    assert !result.empty?
    assert_equal Issue.visible.watched_by(User.current).sort_by(&:id), result.sort_by(&:id)
    User.current = nil
  end

  def test_filter_unwatched_issues
    User.current = User.find(1)
    query = IssueQuery.new(:name => '_', :filters => { 'watcher_id' => {:operator => '!', :values => ['me']}})
    result = find_issues_with_query(query)
    assert_not_nil result
    assert !result.empty?
    assert_equal((Issue.visible - Issue.watched_by(User.current)).sort_by(&:id).size, result.sort_by(&:id).size)
    User.current = nil
  end

  def test_filter_on_custom_field_should_ignore_projects_with_field_disabled
    field = IssueCustomField.generate!(:trackers => Tracker.all, :project_ids => [1, 3, 4], :is_filter => true)
    Issue.generate!(:project_id => 3, :tracker_id => 2, :custom_field_values => {field.id.to_s => 'Foo'})
    Issue.generate!(:project_id => 4, :tracker_id => 2, :custom_field_values => {field.id.to_s => 'Foo'})

    query = IssueQuery.new(:name => '_', :project => Project.find(1))
    query.filters = {"cf_#{field.id}" => {:operator => '=', :values => ['Foo']}}
    assert_equal 2, find_issues_with_query(query).size

    field.project_ids = [1, 3] # Disable the field for project 4
    field.save!
    assert_equal 1, find_issues_with_query(query).size
  end

  def test_filter_on_custom_field_should_ignore_trackers_with_field_disabled
    field = IssueCustomField.generate!(:tracker_ids => [1, 2], :is_for_all => true, :is_filter => true)
    Issue.generate!(:project_id => 1, :tracker_id => 1, :custom_field_values => {field.id.to_s => 'Foo'})
    Issue.generate!(:project_id => 1, :tracker_id => 2, :custom_field_values => {field.id.to_s => 'Foo'})

    query = IssueQuery.new(:name => '_', :project => Project.find(1))
    query.filters = {"cf_#{field.id}" => {:operator => '=', :values => ['Foo']}}
    assert_equal 2, find_issues_with_query(query).size

    field.tracker_ids = [1] # Disable the field for tracker 2
    field.save!
    assert_equal 1, find_issues_with_query(query).size
  end

  def test_filter_on_project_custom_field
    field = ProjectCustomField.create!(:name => 'Client', :is_filter => true, :field_format => 'string')
    CustomValue.create!(:custom_field => field, :customized => Project.find(3), :value => 'Foo')
    CustomValue.create!(:custom_field => field, :customized => Project.find(5), :value => 'Foo')

    query = IssueQuery.new(:name => '_')
    filter_name = "project.cf_#{field.id}"
    assert_include filter_name, query.available_filters.keys
    query.filters = {filter_name => {:operator => '=', :values => ['Foo']}}
    assert_equal [3, 5], find_issues_with_query(query).map(&:project_id).uniq.sort
  end

  def test_filter_on_author_custom_field
    field = UserCustomField.create!(:name => 'Client', :is_filter => true, :field_format => 'string')
    CustomValue.create!(:custom_field => field, :customized => User.find(3), :value => 'Foo')

    query = IssueQuery.new(:name => '_')
    filter_name = "author.cf_#{field.id}"
    assert_include filter_name, query.available_filters.keys
    query.filters = {filter_name => {:operator => '=', :values => ['Foo']}}
    assert_equal [3], find_issues_with_query(query).map(&:author_id).uniq.sort
  end

  def test_filter_on_assigned_to_custom_field
    field = UserCustomField.create!(:name => 'Client', :is_filter => true, :field_format => 'string')
    CustomValue.create!(:custom_field => field, :customized => User.find(3), :value => 'Foo')

    query = IssueQuery.new(:name => '_')
    filter_name = "assigned_to.cf_#{field.id}"
    assert_include filter_name, query.available_filters.keys
    query.filters = {filter_name => {:operator => '=', :values => ['Foo']}}
    assert_equal [3], find_issues_with_query(query).map(&:assigned_to_id).uniq.sort
  end

  def test_filter_on_fixed_version_custom_field
    field = VersionCustomField.create!(:name => 'Client', :is_filter => true, :field_format => 'string')
    CustomValue.create!(:custom_field => field, :customized => Version.find(2), :value => 'Foo')

    query = IssueQuery.new(:name => '_')
    filter_name = "fixed_version.cf_#{field.id}"
    assert_include filter_name, query.available_filters.keys
    query.filters = {filter_name => {:operator => '=', :values => ['Foo']}}
    assert_equal [2], find_issues_with_query(query).map(&:fixed_version_id).uniq.sort
  end

  def test_filter_on_relations_with_a_specific_issue
    IssueRelation.delete_all
    IssueRelation.create!(:relation_type => "relates", :issue_from => Issue.find(1), :issue_to => Issue.find(2))
    IssueRelation.create!(:relation_type => "relates", :issue_from => Issue.find(3), :issue_to => Issue.find(1))

    query = IssueQuery.new(:name => '_')
    query.filters = {"relates" => {:operator => '=', :values => ['1']}}
    assert_equal [2, 3], find_issues_with_query(query).map(&:id).sort

    query = IssueQuery.new(:name => '_')
    query.filters = {"relates" => {:operator => '=', :values => ['2']}}
    assert_equal [1], find_issues_with_query(query).map(&:id).sort
  end

  def test_filter_on_relations_with_any_issues_in_a_project
    IssueRelation.delete_all
    with_settings :cross_project_issue_relations => '1' do
      IssueRelation.create!(:relation_type => "relates", :issue_from => Issue.find(1), :issue_to => Project.find(2).issues.first)
      IssueRelation.create!(:relation_type => "relates", :issue_from => Issue.find(2), :issue_to => Project.find(2).issues.first)
      IssueRelation.create!(:relation_type => "relates", :issue_from => Issue.find(1), :issue_to => Project.find(3).issues.first)
    end

    query = IssueQuery.new(:name => '_')
    query.filters = {"relates" => {:operator => '=p', :values => ['2']}}
    assert_equal [1, 2], find_issues_with_query(query).map(&:id).sort

    query = IssueQuery.new(:name => '_')
    query.filters = {"relates" => {:operator => '=p', :values => ['3']}}
    assert_equal [1], find_issues_with_query(query).map(&:id).sort

    query = IssueQuery.new(:name => '_')
    query.filters = {"relates" => {:operator => '=p', :values => ['4']}}
    assert_equal [], find_issues_with_query(query).map(&:id).sort
  end

  def test_filter_on_relations_with_any_issues_not_in_a_project
    IssueRelation.delete_all
    with_settings :cross_project_issue_relations => '1' do
      IssueRelation.create!(:relation_type => "relates", :issue_from => Issue.find(1), :issue_to => Project.find(2).issues.first)
      #IssueRelation.create!(:relation_type => "relates", :issue_from => Issue.find(2), :issue_to => Project.find(1).issues.first)
      IssueRelation.create!(:relation_type => "relates", :issue_from => Issue.find(1), :issue_to => Project.find(3).issues.first)
    end

    query = IssueQuery.new(:name => '_')
    query.filters = {"relates" => {:operator => '=!p', :values => ['1']}}
    assert_equal [1], find_issues_with_query(query).map(&:id).sort
  end

  def test_filter_on_relations_with_no_issues_in_a_project
    IssueRelation.delete_all
    with_settings :cross_project_issue_relations => '1' do
      IssueRelation.create!(:relation_type => "relates", :issue_from => Issue.find(1), :issue_to => Project.find(2).issues.first)
      IssueRelation.create!(:relation_type => "relates", :issue_from => Issue.find(2), :issue_to => Project.find(3).issues.first)
      IssueRelation.create!(:relation_type => "relates", :issue_to => Project.find(2).issues.first, :issue_from => Issue.find(3))
    end

    query = IssueQuery.new(:name => '_')
    query.filters = {"relates" => {:operator => '!p', :values => ['2']}}
    ids = find_issues_with_query(query).map(&:id).sort
    assert_include 2, ids
    assert_not_include 1, ids
    assert_not_include 3, ids
  end

  def test_filter_on_relations_with_no_issues
    IssueRelation.delete_all
    IssueRelation.create!(:relation_type => "relates", :issue_from => Issue.find(1), :issue_to => Issue.find(2))
    IssueRelation.create!(:relation_type => "relates", :issue_from => Issue.find(3), :issue_to => Issue.find(1))

    query = IssueQuery.new(:name => '_')
    query.filters = {"relates" => {:operator => '!*', :values => ['']}}
    ids = find_issues_with_query(query).map(&:id)
    assert_equal [], ids & [1, 2, 3]
    assert_include 4, ids
  end

  def test_filter_on_relations_with_any_issues
    IssueRelation.delete_all
    IssueRelation.create!(:relation_type => "relates", :issue_from => Issue.find(1), :issue_to => Issue.find(2))
    IssueRelation.create!(:relation_type => "relates", :issue_from => Issue.find(3), :issue_to => Issue.find(1))

    query = IssueQuery.new(:name => '_')
    query.filters = {"relates" => {:operator => '*', :values => ['']}}
    assert_equal [1, 2, 3], find_issues_with_query(query).map(&:id).sort
  end

  def test_filter_on_relations_should_not_ignore_other_filter
    issue = Issue.generate!
    issue1 = Issue.generate!(:status_id => 1)
    issue2 = Issue.generate!(:status_id => 2)
    IssueRelation.create!(:relation_type => "relates", :issue_from => issue, :issue_to => issue1)
    IssueRelation.create!(:relation_type => "relates", :issue_from => issue, :issue_to => issue2)

    query = IssueQuery.new(:name => '_')
    query.filters = {
      "status_id" => {:operator => '=', :values => ['1']},
      "relates" => {:operator => '=', :values => [issue.id.to_s]}
    }
    assert_equal [issue1], find_issues_with_query(query)
  end

  def test_filter_on_parent
    Issue.delete_all
    parent = Issue.generate_with_descendants!
    

    query = IssueQuery.new(:name => '_')
    query.filters = {"parent_id" => {:operator => '=', :values => [parent.id.to_s]}}
    assert_equal parent.children.map(&:id).sort, find_issues_with_query(query).map(&:id).sort

    query.filters = {"parent_id" => {:operator => '~', :values => [parent.id.to_s]}}
    assert_equal parent.descendants.map(&:id).sort, find_issues_with_query(query).map(&:id).sort

    query.filters = {"parent_id" => {:operator => '*', :values => ['']}}
    assert_equal parent.descendants.map(&:id).sort, find_issues_with_query(query).map(&:id).sort

    query.filters = {"parent_id" => {:operator => '!*', :values => ['']}}
    assert_equal [parent.id], find_issues_with_query(query).map(&:id).sort
  end

  def test_filter_on_invalid_parent_should_return_no_results
    query = IssueQuery.new(:name => '_')
    query.filters = {"parent_id" => {:operator => '=', :values => '99999999999'}}
    assert_equal [], find_issues_with_query(query).map(&:id).sort

    query.filters = {"parent_id" => {:operator => '~', :values => '99999999999'}}
    assert_equal [], find_issues_with_query(query)
  end

  def test_filter_on_child
    Issue.delete_all
    parent = Issue.generate_with_descendants!
    child, leaf = parent.children.sort_by(&:id)
    grandchild = child.children.first
    

    query = IssueQuery.new(:name => '_')
    query.filters = {"child_id" => {:operator => '=', :values => [grandchild.id.to_s]}}
    assert_equal [child.id], find_issues_with_query(query).map(&:id).sort

    query.filters = {"child_id" => {:operator => '~', :values => [grandchild.id.to_s]}}
    assert_equal [parent, child].map(&:id).sort, find_issues_with_query(query).map(&:id).sort

    query.filters = {"child_id" => {:operator => '*', :values => ['']}}
    assert_equal [parent, child].map(&:id).sort, find_issues_with_query(query).map(&:id).sort

    query.filters = {"child_id" => {:operator => '!*', :values => ['']}}
    assert_equal [grandchild, leaf].map(&:id).sort, find_issues_with_query(query).map(&:id).sort
  end

  def test_filter_on_invalid_child_should_return_no_results
    query = IssueQuery.new(:name => '_')
    query.filters = {"child_id" => {:operator => '=', :values =>  '99999999999'}}
    assert_equal [], find_issues_with_query(query)

    query.filters = {"child_id" => {:operator => '~', :values =>  '99999999999'}}
    assert_equal [].map(&:id).sort, find_issues_with_query(query)
  end

  def test_statement_should_be_nil_with_no_filters
    q = IssueQuery.new(:name => '_')
    q.filters = {}

    assert q.valid?
    assert_nil q.statement
  end

  def test_default_columns
    q = IssueQuery.new
    assert q.columns.any?
    assert q.inline_columns.any?
    assert q.block_columns.empty?
  end

  def test_set_column_names
    q = IssueQuery.new
    q.column_names = ['tracker', :subject, '', 'unknonw_column']
    assert_equal [:id, :tracker, :subject], q.columns.collect {|c| c.name}
  end

  def test_has_column_should_accept_a_column_name
    q = IssueQuery.new
    q.column_names = ['tracker', :subject]
    assert q.has_column?(:tracker)
    assert !q.has_column?(:category)
  end

  def test_has_column_should_accept_a_column
    q = IssueQuery.new
    q.column_names = ['tracker', :subject]

    tracker_column = q.available_columns.detect {|c| c.name==:tracker}
    assert_kind_of QueryColumn, tracker_column
    category_column = q.available_columns.detect {|c| c.name==:category}
    assert_kind_of QueryColumn, category_column

    assert q.has_column?(tracker_column)
    assert !q.has_column?(category_column)
  end

  def test_inline_and_block_columns
    q = IssueQuery.new
    q.column_names = ['subject', 'description', 'tracker']

    assert_equal [:id, :subject, :tracker], q.inline_columns.map(&:name)
    assert_equal [:description], q.block_columns.map(&:name)
  end

  def test_custom_field_columns_should_be_inline
    q = IssueQuery.new
    columns = q.available_columns.select {|column| column.is_a? QueryCustomFieldColumn}
    assert columns.any?
    assert_nil columns.detect {|column| !column.inline?}
  end

  def test_query_should_preload_spent_hours
    q = IssueQuery.new(:name => '_', :column_names => [:subject, :spent_hours])
    assert q.has_column?(:spent_hours)
    issues = q.issues
    assert_not_nil issues.first.instance_variable_get("@spent_hours")
  end

  def test_groupable_columns_should_include_custom_fields
    q = IssueQuery.new
    column = q.groupable_columns.detect {|c| c.name == :cf_1}
    assert_not_nil column
    assert_kind_of QueryCustomFieldColumn, column
  end

  def test_groupable_columns_should_not_include_multi_custom_fields
    field = CustomField.find(1)
    field.update_attribute :multiple, true

    q = IssueQuery.new
    column = q.groupable_columns.detect {|c| c.name == :cf_1}
    assert_nil column
  end

  def test_groupable_columns_should_include_user_custom_fields
    cf = IssueCustomField.create!(:name => 'User', :is_for_all => true, :tracker_ids => [1], :field_format => 'user')

    q = IssueQuery.new
    assert q.groupable_columns.detect {|c| c.name == "cf_#{cf.id}".to_sym}
  end

  def test_groupable_columns_should_include_version_custom_fields
    cf = IssueCustomField.create!(:name => 'User', :is_for_all => true, :tracker_ids => [1], :field_format => 'version')

    q = IssueQuery.new
    assert q.groupable_columns.detect {|c| c.name == "cf_#{cf.id}".to_sym}
  end

  def test_grouped_with_valid_column
    q = IssueQuery.new(:group_by => 'status')
    assert q.grouped?
    assert_not_nil q.group_by_column
    assert_equal :status, q.group_by_column.name
    assert_not_nil q.group_by_statement
    assert_equal 'status', q.group_by_statement
  end

  def test_grouped_with_invalid_column
    q = IssueQuery.new(:group_by => 'foo')
    assert !q.grouped?
    assert_nil q.group_by_column
    assert_nil q.group_by_statement
  end

  def test_sortable_columns_should_sort_assignees_according_to_user_format_setting
    with_settings :user_format => 'lastname_coma_firstname' do
      q = IssueQuery.new
      assert q.sortable_columns.has_key?('assigned_to')
      assert_equal %w(users.lastname users.firstname users.id), q.sortable_columns['assigned_to']
    end
  end

  def test_sortable_columns_should_sort_authors_according_to_user_format_setting
    with_settings :user_format => 'lastname_coma_firstname' do
      q = IssueQuery.new
      assert q.sortable_columns.has_key?('author')
      assert_equal %w(authors.lastname authors.firstname authors.id), q.sortable_columns['author']
    end
  end

  def test_sortable_columns_should_include_custom_field
    q = IssueQuery.new
    assert q.sortable_columns['cf_1']
  end

  def test_sortable_columns_should_not_include_multi_custom_field
    field = CustomField.find(1)
    field.update_attribute :multiple, true

    q = IssueQuery.new
    assert !q.sortable_columns['cf_1']
  end

  def test_default_sort
    q = IssueQuery.new
    assert_equal [], q.sort_criteria
  end

  def test_set_sort_criteria_with_hash
    q = IssueQuery.new
    q.sort_criteria = {'0' => ['priority', 'desc'], '2' => ['tracker']}
    assert_equal [['priority', 'desc'], ['tracker', 'asc']], q.sort_criteria
  end

  def test_set_sort_criteria_with_array
    q = IssueQuery.new
    q.sort_criteria = [['priority', 'desc'], 'tracker']
    assert_equal [['priority', 'desc'], ['tracker', 'asc']], q.sort_criteria
  end

  def test_create_query_with_sort
    q = IssueQuery.new(:name => 'Sorted')
    q.sort_criteria = [['priority', 'desc'], 'tracker']
    assert q.save
    q.reload
    assert_equal [['priority', 'desc'], ['tracker', 'asc']], q.sort_criteria
  end

  def test_sort_by_string_custom_field_asc
    q = IssueQuery.new
    c = q.available_columns.find {|col| col.is_a?(QueryCustomFieldColumn) && col.custom_field.field_format == 'string' }
    assert c
    assert c.sortable
    issues = q.issues(:order => "#{c.sortable} ASC")
    values = issues.collect {|i| i.custom_value_for(c.custom_field).to_s}
    assert !values.empty?
    assert_equal values.sort, values
  end

  def test_sort_by_string_custom_field_desc
    q = IssueQuery.new
    c = q.available_columns.find {|col| col.is_a?(QueryCustomFieldColumn) && col.custom_field.field_format == 'string' }
    assert c
    assert c.sortable
    issues = q.issues(:order => "#{c.sortable} DESC")
    values = issues.collect {|i| i.custom_value_for(c.custom_field).to_s}
    assert !values.empty?
    assert_equal values.sort.reverse, values
  end

  def test_sort_by_float_custom_field_asc
    q = IssueQuery.new
    c = q.available_columns.find {|col| col.is_a?(QueryCustomFieldColumn) && col.custom_field.field_format == 'float' }
    assert c
    assert c.sortable
    issues = q.issues(:order => "#{c.sortable} ASC")
    values = issues.collect {|i| begin; Kernel.Float(i.custom_value_for(c.custom_field).to_s); rescue; nil; end}.compact
    assert !values.empty?
    assert_equal values.sort, values
  end

  def test_invalid_query_should_raise_query_statement_invalid_error
    q = IssueQuery.new
    assert_raise Query::StatementInvalid do
      q.issues(:conditions => "foo = 1")
    end
  end

  def test_issue_count
    q = IssueQuery.new(:name => '_')
    issue_count = q.issue_count
    assert_equal q.issues.size, issue_count
  end

  def test_issue_count_with_archived_issues
    p = Project.generate! do |project|
      project.status = Project::STATUS_ARCHIVED
    end
    i = Issue.generate!( :project => p, :tracker => p.trackers.first )
    assert !i.visible?

    test_issue_count
  end

  def test_issue_count_by_association_group
    q = IssueQuery.new(:name => '_', :group_by => 'assigned_to')
    count_by_group = q.issue_count_by_group
    assert_kind_of Hash, count_by_group
    assert_equal %w(NilClass User), count_by_group.keys.collect {|k| k.class.name}.uniq.sort
    assert_equal %w(Fixnum), count_by_group.values.collect {|k| k.class.name}.uniq
    assert count_by_group.has_key?(User.find(3))
  end

  def test_issue_count_by_list_custom_field_group
    q = IssueQuery.new(:name => '_', :group_by => 'cf_1')
    count_by_group = q.issue_count_by_group
    assert_kind_of Hash, count_by_group
    assert_equal %w(NilClass String), count_by_group.keys.collect {|k| k.class.name}.uniq.sort
    assert_equal %w(Fixnum), count_by_group.values.collect {|k| k.class.name}.uniq
    assert count_by_group.has_key?('MySQL')
  end

  def test_issue_count_by_date_custom_field_group
    q = IssueQuery.new(:name => '_', :group_by => 'cf_8')
    count_by_group = q.issue_count_by_group
    assert_kind_of Hash, count_by_group
    assert_equal %w(Date NilClass), count_by_group.keys.collect {|k| k.class.name}.uniq.sort
    assert_equal %w(Fixnum), count_by_group.values.collect {|k| k.class.name}.uniq
  end

  def test_issue_count_with_nil_group_only
    Issue.update_all("assigned_to_id = NULL")

    q = IssueQuery.new(:name => '_', :group_by => 'assigned_to')
    count_by_group = q.issue_count_by_group
    assert_kind_of Hash, count_by_group
    assert_equal 1, count_by_group.keys.size
    assert_nil count_by_group.keys.first
  end

  def test_issue_ids
    q = IssueQuery.new(:name => '_')
    order = "issues.subject, issues.id"
    issues = q.issues(:order => order)
    assert_equal issues.map(&:id), q.issue_ids(:order => order)
  end

  def test_label_for
    set_language_if_valid 'en'
    q = IssueQuery.new
    assert_equal 'Assignee', q.label_for('assigned_to_id')
  end

  def test_label_for_fr
    set_language_if_valid 'fr'
    q = IssueQuery.new
    assert_equal "Assign\xc3\xa9 \xc3\xa0".force_encoding('UTF-8'), q.label_for('assigned_to_id')
  end

  def test_editable_by
    admin = User.find(1)
    manager = User.find(2)
    developer = User.find(3)

    # Public query on project 1
    q = IssueQuery.find(1)
    assert q.editable_by?(admin)
    assert q.editable_by?(manager)
    assert !q.editable_by?(developer)

    # Private query on project 1
    q = IssueQuery.find(2)
    assert q.editable_by?(admin)
    assert !q.editable_by?(manager)
    assert q.editable_by?(developer)

    # Private query for all projects
    q = IssueQuery.find(3)
    assert q.editable_by?(admin)
    assert !q.editable_by?(manager)
    assert q.editable_by?(developer)

    # Public query for all projects
    q = IssueQuery.find(4)
    assert q.editable_by?(admin)
    assert !q.editable_by?(manager)
    assert !q.editable_by?(developer)
  end

  def test_visible_scope
    query_ids = IssueQuery.visible(User.anonymous).map(&:id)

    assert query_ids.include?(1), 'public query on public project was not visible'
    assert query_ids.include?(4), 'public query for all projects was not visible'
    assert !query_ids.include?(2), 'private query on public project was visible'
    assert !query_ids.include?(3), 'private query for all projects was visible'
    assert !query_ids.include?(7), 'public query on private project was visible'
  end

  def test_query_with_public_visibility_should_be_visible_to_anyone
    q = IssueQuery.create!(:name => 'Query', :visibility => IssueQuery::VISIBILITY_PUBLIC)

    assert q.visible?(User.anonymous)
    assert IssueQuery.visible(User.anonymous).find_by_id(q.id)

    assert q.visible?(User.find(7))
    assert IssueQuery.visible(User.find(7)).find_by_id(q.id)

    assert q.visible?(User.find(2))
    assert IssueQuery.visible(User.find(2)).find_by_id(q.id)

    assert q.visible?(User.find(1))
    assert IssueQuery.visible(User.find(1)).find_by_id(q.id)
  end

  def test_query_with_roles_visibility_should_be_visible_to_user_with_role
    q = IssueQuery.create!(:name => 'Query', :visibility => IssueQuery::VISIBILITY_ROLES, :role_ids => [1,2])

    assert !q.visible?(User.anonymous)
    assert_nil IssueQuery.visible(User.anonymous).find_by_id(q.id)

    assert !q.visible?(User.find(7))
    assert_nil IssueQuery.visible(User.find(7)).find_by_id(q.id)

    assert q.visible?(User.find(2))
    assert IssueQuery.visible(User.find(2)).find_by_id(q.id)

    assert q.visible?(User.find(1))
    assert IssueQuery.visible(User.find(1)).find_by_id(q.id)
  end

  def test_query_with_private_visibility_should_be_visible_to_owner
    q = IssueQuery.create!(:name => 'Query', :visibility => IssueQuery::VISIBILITY_PRIVATE, :user => User.find(7))

    assert !q.visible?(User.anonymous)
    assert_nil IssueQuery.visible(User.anonymous).find_by_id(q.id)

    assert q.visible?(User.find(7))
    assert IssueQuery.visible(User.find(7)).find_by_id(q.id)

    assert !q.visible?(User.find(2))
    assert_nil IssueQuery.visible(User.find(2)).find_by_id(q.id)

    assert q.visible?(User.find(1))
    assert_nil IssueQuery.visible(User.find(1)).find_by_id(q.id)
  end

  test "#available_filters should include users of visible projects in cross-project view" do
    users = IssueQuery.new.available_filters["assigned_to_id"]
    assert_not_nil users
    assert users[:values].map{|u|u[1]}.include?("3")
  end

  test "#available_filters should include users of subprojects" do
    user1 = User.generate!
    user2 = User.generate!
    project = Project.find(1)
    Member.create!(:principal => user1, :project => project.children.visible.first, :role_ids => [1])

    users = IssueQuery.new(:project => project).available_filters["assigned_to_id"]
    assert_not_nil users
    assert users[:values].map{|u|u[1]}.include?(user1.id.to_s)
    assert !users[:values].map{|u|u[1]}.include?(user2.id.to_s)
  end

  test "#available_filters should include visible projects in cross-project view" do
    projects = IssueQuery.new.available_filters["project_id"]
    assert_not_nil projects
    assert projects[:values].map{|u|u[1]}.include?("1")
  end

  test "#available_filters should include 'member_of_group' filter" do
    query = IssueQuery.new
    assert query.available_filters.keys.include?("member_of_group")
    assert_equal :list_optional, query.available_filters["member_of_group"][:type]
    assert query.available_filters["member_of_group"][:values].present?
    assert_equal Group.givable.sort.map {|g| [g.name, g.id.to_s]},
      query.available_filters["member_of_group"][:values].sort
  end

  test "#available_filters should include 'assigned_to_role' filter" do
    query = IssueQuery.new
    assert query.available_filters.keys.include?("assigned_to_role")
    assert_equal :list_optional, query.available_filters["assigned_to_role"][:type]

    assert query.available_filters["assigned_to_role"][:values].include?(['Manager','1'])
    assert query.available_filters["assigned_to_role"][:values].include?(['Developer','2'])
    assert query.available_filters["assigned_to_role"][:values].include?(['Reporter','3'])

    assert ! query.available_filters["assigned_to_role"][:values].include?(['Non member','4'])
    assert ! query.available_filters["assigned_to_role"][:values].include?(['Anonymous','5'])
  end

  def test_available_filters_should_include_custom_field_according_to_user_visibility
    visible_field = IssueCustomField.generate!(:is_for_all => true, :is_filter => true, :visible => true)
    hidden_field = IssueCustomField.generate!(:is_for_all => true, :is_filter => true, :visible => false, :role_ids => [1])

    with_current_user User.find(3) do
      query = IssueQuery.new
      assert_include "cf_#{visible_field.id}", query.available_filters.keys
      assert_not_include "cf_#{hidden_field.id}", query.available_filters.keys
    end
  end

  def test_available_columns_should_include_custom_field_according_to_user_visibility
    visible_field = IssueCustomField.generate!(:is_for_all => true, :is_filter => true, :visible => true)
    hidden_field = IssueCustomField.generate!(:is_for_all => true, :is_filter => true, :visible => false, :role_ids => [1])

    with_current_user User.find(3) do
      query = IssueQuery.new
      assert_include :"cf_#{visible_field.id}", query.available_columns.map(&:name)
      assert_not_include :"cf_#{hidden_field.id}", query.available_columns.map(&:name)
    end
  end

  def setup_member_of_group
    Group.destroy_all # No fixtures
    @user_in_group = User.generate!
    @second_user_in_group = User.generate!
    @user_in_group2 = User.generate!
    @user_not_in_group = User.generate!

    @group = Group.generate!.reload
    @group.users << @user_in_group
    @group.users << @second_user_in_group

    @group2 = Group.generate!.reload
    @group2.users << @user_in_group2

    @query = IssueQuery.new(:name => '_')
  end

  test "member_of_group filter should search assigned to for users in the group" do
    setup_member_of_group
    @query.add_filter('member_of_group', '=', [@group.id.to_s])

    assert_query_statement_includes @query, "#{Issue.table_name}.assigned_to_id IN ('#{@user_in_group.id}','#{@second_user_in_group.id}','#{@group.id}')"
    assert_find_issues_with_query_is_successful @query
  end

  test "member_of_group filter should search not assigned to any group member (none)" do
    setup_member_of_group
    @query.add_filter('member_of_group', '!*', [''])

    # Users not in a group
    assert_query_statement_includes @query, "#{Issue.table_name}.assigned_to_id IS NULL OR #{Issue.table_name}.assigned_to_id NOT IN ('#{@user_in_group.id}','#{@second_user_in_group.id}','#{@user_in_group2.id}','#{@group.id}','#{@group2.id}')"
    assert_find_issues_with_query_is_successful @query
  end

  test "member_of_group filter should search assigned to any group member (all)" do
    setup_member_of_group
    @query.add_filter('member_of_group', '*', [''])

    # Only users in a group
    assert_query_statement_includes @query, "#{Issue.table_name}.assigned_to_id IN ('#{@user_in_group.id}','#{@second_user_in_group.id}','#{@user_in_group2.id}','#{@group.id}','#{@group2.id}')"
    assert_find_issues_with_query_is_successful @query
  end

  test "member_of_group filter should return an empty set with = empty group" do
    setup_member_of_group
    @empty_group = Group.generate!
    @query.add_filter('member_of_group', '=', [@empty_group.id.to_s])

    assert_equal [], find_issues_with_query(@query)
  end

  test "member_of_group filter should return issues with ! empty group" do
    setup_member_of_group
    @empty_group = Group.generate!
    @query.add_filter('member_of_group', '!', [@empty_group.id.to_s])

    assert_find_issues_with_query_is_successful @query
  end

  def setup_assigned_to_role
    @manager_role = Role.find_by_name('Manager')
    @developer_role = Role.find_by_name('Developer')

    @project = Project.generate!
    @manager = User.generate!
    @developer = User.generate!
    @boss = User.generate!
    @guest = User.generate!
    User.add_to_project(@manager, @project, @manager_role)
    User.add_to_project(@developer, @project, @developer_role)
    User.add_to_project(@boss, @project, [@manager_role, @developer_role])

    @issue1 = Issue.generate!(:project => @project, :assigned_to_id => @manager.id)
    @issue2 = Issue.generate!(:project => @project, :assigned_to_id => @developer.id)
    @issue3 = Issue.generate!(:project => @project, :assigned_to_id => @boss.id)
    @issue4 = Issue.generate!(:project => @project, :assigned_to_id => @guest.id)
    @issue5 = Issue.generate!(:project => @project)

    @query = IssueQuery.new(:name => '_', :project => @project)
  end

  test "assigned_to_role filter should search assigned to for users with the Role" do
    setup_assigned_to_role
    @query.add_filter('assigned_to_role', '=', [@manager_role.id.to_s])

    assert_query_result [@issue1, @issue3], @query
  end

  test "assigned_to_role filter should search assigned to for users with the Role on the issue project" do
    setup_assigned_to_role
    other_project = Project.generate!
    User.add_to_project(@developer, other_project, @manager_role)
    @query.add_filter('assigned_to_role', '=', [@manager_role.id.to_s])

    assert_query_result [@issue1, @issue3], @query
  end

  test "assigned_to_role filter should return an empty set with empty role" do
    setup_assigned_to_role
    @empty_role = Role.generate!
    @query.add_filter('assigned_to_role', '=', [@empty_role.id.to_s])

    assert_query_result [], @query
  end

  test "assigned_to_role filter should search assigned to for users without the Role" do
    setup_assigned_to_role
    @query.add_filter('assigned_to_role', '!', [@manager_role.id.to_s])

    assert_query_result [@issue2, @issue4, @issue5], @query
  end

  test "assigned_to_role filter should search assigned to for users not assigned to any Role (none)" do
    setup_assigned_to_role
    @query.add_filter('assigned_to_role', '!*', [''])

    assert_query_result [@issue4, @issue5], @query
  end

  test "assigned_to_role filter should search assigned to for users assigned to any Role (all)" do
    setup_assigned_to_role
    @query.add_filter('assigned_to_role', '*', [''])

    assert_query_result [@issue1, @issue2, @issue3], @query
  end

  test "assigned_to_role filter should return issues with ! empty role" do
    setup_assigned_to_role
    @empty_role = Role.generate!
    @query.add_filter('assigned_to_role', '!', [@empty_role.id.to_s])

    assert_query_result [@issue1, @issue2, @issue3, @issue4, @issue5], @query
  end

  def test_query_column_should_accept_a_symbol_as_caption
    set_language_if_valid 'en'
    c = QueryColumn.new('foo', :caption => :general_text_Yes)
    assert_equal 'Yes', c.caption
  end

  def test_query_column_should_accept_a_proc_as_caption
    c = QueryColumn.new('foo', :caption => lambda {'Foo'})
    assert_equal 'Foo', c.caption
  end
end
