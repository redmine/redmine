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

require File.expand_path('../../test_helper', __FILE__)

class IssueTest < ActiveSupport::TestCase
  fixtures :projects, :users, :email_addresses, :user_preferences, :members, :member_roles, :roles,
           :groups_users,
           :trackers, :projects_trackers,
           :enabled_modules,
           :versions,
           :issue_statuses, :issue_categories, :issue_relations, :workflows,
           :enumerations,
           :issues, :journals, :journal_details,
           :watchers,
           :custom_fields, :custom_fields_projects, :custom_fields_trackers, :custom_values,
           :time_entries

  include Redmine::I18n

  def setup
    User.current = nil
    set_language_if_valid 'en'
  end

  def teardown
    User.current = nil
  end

  def test_initialize
    issue = Issue.new

    assert_nil issue.project_id
    assert_nil issue.tracker_id
    assert_nil issue.status_id
    assert_nil issue.author_id
    assert_nil issue.assigned_to_id
    assert_nil issue.category_id

    assert_equal IssuePriority.default, issue.priority
  end

  def test_create
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 3,
                      :status_id => 1, :priority => IssuePriority.all.first,
                      :subject => 'test_create',
                      :description => 'IssueTest#test_create', :estimated_hours => '1:30')
    assert issue.save
    issue.reload
    assert_equal 1.5, issue.estimated_hours
  end

  def test_create_minimal
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 3, :subject => 'test_create')
    assert issue.save
    assert_equal issue.tracker.default_status, issue.status
    assert issue.description.nil?
    assert_nil issue.estimated_hours
  end

  def test_create_with_all_fields_disabled
    tracker = Tracker.find(1)
    tracker.core_fields = []
    tracker.save!

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 3, :subject => 'test_create_with_all_fields_disabled')
    assert_save issue
  end

  def test_start_date_format_should_be_validated
    set_language_if_valid 'en'
    ['2012', 'ABC', '2012-15-20'].each do |invalid_date|
      issue = Issue.new(:start_date => invalid_date)
      assert !issue.valid?
      assert_include 'Start date is not a valid date', issue.errors.full_messages, "No error found for invalid date #{invalid_date}"
    end
  end

  def test_due_date_format_should_be_validated
    set_language_if_valid 'en'
    ['2012', 'ABC', '2012-15-20'].each do |invalid_date|
      issue = Issue.new(:due_date => invalid_date)
      assert !issue.valid?
      assert_include 'Due date is not a valid date', issue.errors.full_messages, "No error found for invalid date #{invalid_date}"
    end
  end

  def test_due_date_lesser_than_start_date_should_not_validate
    set_language_if_valid 'en'
    issue = Issue.new(:start_date => '2012-10-06', :due_date => '2012-10-02')
    assert !issue.valid?
    assert_include 'Due date must be greater than start date', issue.errors.full_messages
  end

  def test_start_date_lesser_than_soonest_start_should_not_validate_on_create
    issue = Issue.generate(:start_date => '2013-06-04')
    issue.stubs(:soonest_start).returns(Date.parse('2013-06-10'))
    assert !issue.valid?
    assert_include "Start date cannot be earlier than 06/10/2013 because of preceding issues", issue.errors.full_messages
  end

  def test_start_date_lesser_than_soonest_start_should_not_validate_on_update_if_changed
    issue = Issue.generate!(:start_date => '2013-06-04')
    issue.stubs(:soonest_start).returns(Date.parse('2013-06-10'))
    issue.start_date = '2013-06-07'
    assert !issue.valid?
    assert_include "Start date cannot be earlier than 06/10/2013 because of preceding issues", issue.errors.full_messages
  end

  def test_start_date_lesser_than_soonest_start_should_validate_on_update_if_unchanged
    issue = Issue.generate!(:start_date => '2013-06-04')
    issue.stubs(:soonest_start).returns(Date.parse('2013-06-10'))
    assert issue.valid?
  end

  def test_estimated_hours_should_be_validated
    set_language_if_valid 'en'
    ['-2', '123abc'].each do |invalid|
      issue = Issue.new(:estimated_hours => invalid)
      assert !issue.valid?
      assert_include 'Estimated time is invalid', issue.errors.full_messages
    end
  end

  def test_create_with_required_custom_field
    set_language_if_valid 'en'
    field = IssueCustomField.find_by_name('Database')
    field.update!(:is_required => true)

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 1,
                      :status_id => 1, :subject => 'test_create',
                      :description => 'IssueTest#test_create_with_required_custom_field')
    assert issue.available_custom_fields.include?(field)
    # No value for the custom field
    assert !issue.save
    assert_equal ["Database cannot be blank"], issue.errors.full_messages
    # Blank value
    issue.custom_field_values = {field.id => ''}
    assert !issue.save
    assert_equal ["Database cannot be blank"], issue.errors.full_messages
    # Invalid value
    issue.custom_field_values = {field.id => 'SQLServer'}
    assert !issue.save
    assert_equal ["Database is not included in the list"], issue.errors.full_messages
    # Valid value
    issue.custom_field_values = {field.id => 'PostgreSQL'}
    assert issue.save
    issue.reload
    assert_equal 'PostgreSQL', issue.custom_value_for(field).value
  end

  def test_create_with_group_assignment
    with_settings :issue_group_assignment => '1' do
      assert Issue.new(:project_id => 2, :tracker_id => 1, :author_id => 1,
                       :subject => 'Group assignment',
                       :assigned_to_id => 11).save
      issue = Issue.order('id DESC').first
      assert_kind_of Group, issue.assigned_to
      assert_equal Group.find(11), issue.assigned_to
    end
  end

  def test_create_with_parent_issue_id
    issue = Issue.new(:project_id => 1, :tracker_id => 1,
                      :author_id => 1, :subject => 'Group assignment',
                      :parent_issue_id => 1)
    assert_save issue
    assert_equal 1, issue.parent_issue_id
    assert_equal Issue.find(1), issue.parent
  end

  def test_create_with_sharp_parent_issue_id
    issue = Issue.new(:project_id => 1, :tracker_id => 1,
                      :author_id => 1, :subject => 'Group assignment',
                      :parent_issue_id => "#1")
    assert_save issue
    assert_equal 1, issue.parent_issue_id
    assert_equal Issue.find(1), issue.parent
  end

  def test_create_with_invalid_parent_issue_id
    set_language_if_valid 'en'
    issue = Issue.new(:project_id => 1, :tracker_id => 1,
                      :author_id => 1, :subject => 'Group assignment',
                      :parent_issue_id => '01ABC')
    assert !issue.save
    assert_equal '01ABC', issue.parent_issue_id
    assert_include 'Parent task is invalid', issue.errors.full_messages
  end

  def test_create_with_invalid_sharp_parent_issue_id
    set_language_if_valid 'en'
    issue = Issue.new(:project_id => 1, :tracker_id => 1,
                      :author_id => 1, :subject => 'Group assignment',
                      :parent_issue_id => '#01ABC')
    assert !issue.save
    assert_equal '#01ABC', issue.parent_issue_id
    assert_include 'Parent task is invalid', issue.errors.full_messages
  end

  def assert_visibility_match(user, issues)
    assert_equal issues.collect(&:id).sort, Issue.all.select {|issue| issue.visible?(user)}.collect(&:id).sort
  end

  def test_create_with_emoji_character
    skip if Redmine::Database.mysql? && !is_mysql_utf8mb4

    set_language_if_valid 'en'
    issue = Issue.new(:project_id => 1, :tracker_id => 1,
                      :author_id => 1, :subject => 'Group assignment',
                      :description => 'Hello 😀')
    assert issue.save
    assert_equal 'Hello 😀', issue.description
  end

  def test_visible_scope_for_anonymous
    # Anonymous user should see issues of public projects only
    issues = Issue.visible(User.anonymous).to_a
    assert issues.any?
    assert_nil issues.detect {|issue| !issue.project.is_public?}
    assert_nil issues.detect {|issue| issue.is_private?}
    assert_visibility_match User.anonymous, issues
  end

  def test_visible_scope_for_anonymous_without_view_issues_permissions
    # Anonymous user should not see issues without permission
    Role.anonymous.remove_permission!(:view_issues)
    issues = Issue.visible(User.anonymous).to_a
    assert issues.empty?
    assert_visibility_match User.anonymous, issues
  end

  def test_visible_scope_for_anonymous_without_view_issues_permissions_and_membership
    Role.anonymous.remove_permission!(:view_issues)
    Member.create!(:project_id => 1, :principal => Group.anonymous, :role_ids => [2])

    issues = Issue.visible(User.anonymous).all
    assert issues.any?
    assert_equal [1], issues.map(&:project_id).uniq.sort
    assert_visibility_match User.anonymous, issues
  end

  def test_anonymous_should_not_see_private_issues_with_issues_visibility_set_to_default
    Role.anonymous.update!(:issues_visibility => 'default')
    issue = Issue.generate!(:author => User.anonymous, :is_private => true)
    assert_not Issue.where(:id => issue.id).visible(User.anonymous).exists?
    assert !issue.visible?(User.anonymous)
  end

  def test_anonymous_should_not_see_private_issues_with_issues_visibility_set_to_own
    assert Role.anonymous.update!(:issues_visibility => 'own')
    issue = Issue.generate!(:author => User.anonymous, :is_private => true)
    assert_not Issue.where(:id => issue.id).visible(User.anonymous).exists?
    assert !issue.visible?(User.anonymous)
  end

  def test_visible_scope_for_non_member
    user = User.find(9)
    assert user.projects.empty?
    # Non member user should see issues of public projects only
    issues = Issue.visible(user).to_a
    assert issues.any?
    assert_nil issues.detect {|issue| !issue.project.is_public?}
    assert_nil issues.detect {|issue| issue.is_private?}
    assert_visibility_match user, issues
  end

  def test_visible_scope_for_non_member_with_own_issues_visibility
    Role.non_member.update! :issues_visibility => 'own'
    Issue.create!(:project_id => 1, :tracker_id => 1, :author_id => 9, :subject => 'Issue by non member')
    user = User.find(9)

    issues = Issue.visible(user).to_a
    assert issues.any?
    assert_nil issues.detect {|issue| issue.author != user}
    assert_visibility_match user, issues
  end

  def test_visible_scope_for_non_member_without_view_issues_permissions
    # Non member user should not see issues without permission
    Role.non_member.remove_permission!(:view_issues)
    user = User.find(9)
    assert user.projects.empty?
    issues = Issue.visible(user).to_a
    assert issues.empty?
    assert_visibility_match user, issues
  end

  def test_visible_scope_for_non_member_without_view_issues_permissions_and_membership
    Role.non_member.remove_permission!(:view_issues)
    Member.create!(:project_id => 1, :principal => Group.non_member, :role_ids => [2])
    user = User.find(9)

    issues = Issue.visible(user).all
    assert issues.any?
    assert_equal [1], issues.map(&:project_id).uniq.sort
    assert_visibility_match user, issues
  end

  def test_visible_scope_for_member
    user = User.find(9)
    # User should see issues of projects for which user has view_issues permissions only
    Role.non_member.remove_permission!(:view_issues)
    Member.create!(:principal => user, :project_id => 3, :role_ids => [2])
    issues = Issue.visible(user).to_a
    assert issues.any?
    assert_nil issues.detect {|issue| issue.project_id != 3}
    assert_nil issues.detect {|issue| issue.is_private?}
    assert_visibility_match user, issues
  end

  def test_visible_scope_for_member_without_view_issues_permission_and_non_member_role_having_the_permission
    Role.non_member.add_permission!(:view_issues)
    Role.find(1).remove_permission!(:view_issues)
    user = User.find(2)

    assert_equal 0, Issue.where(:project_id => 1).visible(user).count
    assert_equal false, Issue.where(:project_id => 1).first.visible?(user)
  end

  def test_visible_scope_with_custom_non_member_role_having_restricted_permission
    role = Role.generate!(:permissions => [:view_project])
    assert Role.non_member.has_permission?(:view_issues)
    user = User.generate!
    Member.create!(:principal => Group.non_member, :project_id => 1, :roles => [role])

    issues = Issue.visible(user).to_a
    assert issues.any?
    assert_nil issues.detect {|issue| issue.project_id == 1}
  end

  def test_visible_scope_with_custom_non_member_role_having_extended_permission
    role = Role.generate!(:permissions => [:view_project, :view_issues])
    Role.non_member.remove_permission!(:view_issues)
    user = User.generate!
    Member.create!(:principal => Group.non_member, :project_id => 1, :roles => [role])

    issues = Issue.visible(user).to_a
    assert issues.any?
    assert_not_nil issues.detect {|issue| issue.project_id == 1}
  end

  def test_visible_scope_for_member_with_groups_should_return_assigned_issues
    user = User.find(8)
    assert user.groups.any?
    group = user.groups.first
    Member.create!(:principal => group, :project_id => 1, :role_ids => [2])
    Role.non_member.remove_permission!(:view_issues)

    with_settings :issue_group_assignment => '1' do
      issue = Issue.create!(:project_id => 1, :tracker_id => 1, :author_id => 3,
        :status_id => 1, :priority => IssuePriority.all.first,
        :subject => 'Assignment test',
        :assigned_to => group,
        :is_private => true)

      Role.find(2).update! :issues_visibility => 'default'
      issues = Issue.visible(User.find(8)).to_a
      assert issues.any?
      assert issues.include?(issue)

      Role.find(2).update! :issues_visibility => 'own'
      issues = Issue.visible(User.find(8)).to_a
      assert issues.any?
      assert_include issue, issues
    end
  end

  def test_visible_scope_for_member_with_limited_tracker_ids
    role = Role.find(1)
    role.set_permission_trackers :view_issues, [2]
    role.save!
    user = User.find(2)

    issues = Issue.where(:project_id => 1).visible(user).to_a
    assert issues.any?
    assert_equal [2], issues.map(&:tracker_id).uniq

    assert Issue.where(:project_id => 1).all? {|issue| issue.visible?(user) ^ issue.tracker_id != 2}
  end

  def test_visible_scope_should_consider_tracker_ids_on_each_project
    user = User.generate!

    project1 = Project.generate!
    role1 = Role.generate!
    role1.add_permission! :view_issues
    role1.set_permission_trackers :view_issues, :all
    role1.save!
    User.add_to_project(user, project1, role1)

    project2 = Project.generate!
    role2 = Role.generate!
    role2.add_permission! :view_issues
    role2.set_permission_trackers :view_issues, [2]
    role2.save!
    User.add_to_project(user, project2, role2)

    visible_issues = [
      Issue.generate!(:project => project1, :tracker_id => 1),
      Issue.generate!(:project => project1, :tracker_id => 2),
      Issue.generate!(:project => project2, :tracker_id => 2)
    ]
    hidden_issue = Issue.generate!(:project => project2, :tracker_id => 1)

    issues = Issue.where(:project_id => [project1.id, project2.id]).visible(user)
    assert_equal visible_issues.map(&:id), issues.ids.sort

    assert visible_issues.all? {|issue| issue.visible?(user)}
    assert !hidden_issue.visible?(user)
  end

  def test_visible_scope_should_not_consider_roles_without_view_issues_permission
    user = User.generate!
    role1 = Role.generate!
    role1.remove_permission! :view_issues
    role1.set_permission_trackers :view_issues, :all
    role1.save!
    role2 = Role.generate!
    role2.add_permission! :view_issues
    role2.set_permission_trackers :view_issues, [2]
    role2.save!
    User.add_to_project(user, Project.find(1), [role1, role2])

    issues = Issue.where(:project_id => 1).visible(user).to_a
    assert issues.any?
    assert_equal [2], issues.map(&:tracker_id).uniq

    assert Issue.where(:project_id => 1).all? {|issue| issue.visible?(user) ^ issue.tracker_id != 2}
  end

  def test_visible_scope_for_admin
    user = User.find(1)
    user.members.each(&:destroy)
    assert user.projects.empty?
    issues = Issue.visible(user).to_a
    assert issues.any?
    # Admin should see issues on private projects that admin does not belong to
    assert issues.detect {|issue| !issue.project.is_public?}
    # Admin should see private issues of other users
    assert issues.detect {|issue| issue.is_private? && issue.author != user}
    assert_visibility_match user, issues
  end

  def test_visible_scope_with_project
    project = Project.find(1)
    issues = Issue.visible(User.find(2), :project => project).to_a
    projects = issues.collect(&:project).uniq
    assert_equal 1, projects.size
    assert_equal project, projects.first
  end

  def test_visible_scope_with_project_and_subprojects
    project = Project.find(1)
    issues = Issue.visible(User.find(2), :project => project, :with_subprojects => true).to_a
    projects = issues.collect(&:project).uniq
    assert projects.size > 1
    assert_equal [], projects.select {|p| !p.is_or_is_descendant_of?(project)}
  end

  def test_visible_and_nested_set_scopes
    user = User.generate!
    Member.create!(:project_id => 1, :principal => user, :role_ids => [1])
    parent = Issue.generate!(:assigned_to => user)
    assert parent.visible?(user)
    child1 = Issue.generate!(:parent_issue_id => parent.id, :assigned_to => user)
    child2 = Issue.generate!(:parent_issue_id => parent.id, :assigned_to => user)
    parent.reload
    child1.reload
    child2.reload
    assert child1.visible?(user)
    assert child2.visible?(user)
    assert_equal 2, parent.descendants.count
    assert_equal 2, parent.descendants.visible(user).count
    # awesome_nested_set 2-1-stable branch has regression.
    # https://github.com/collectiveidea/awesome_nested_set/commit/3d5ac746542b564f6586c2316180254b088bebb6
    # ActiveRecord::StatementInvalid: SQLite3::SQLException: ambiguous column name: lft:
    assert_equal 2, parent.descendants.collect{|i| i}.size
    assert_equal 2, parent.descendants.visible(user).collect{|i| i}.size
  end

  def test_visible_scope_with_unsaved_user_should_not_raise_an_error
    user = User.new
    assert_nothing_raised do
      Issue.visible(user).to_a
    end
  end

  def test_open_scope
    issues = Issue.open.to_a
    assert_nil issues.detect(&:closed?)
  end

  def test_open_scope_with_arg
    issues = Issue.open(false).to_a
    assert_equal issues, issues.select(&:closed?)
  end

  def test_fixed_version_scope_with_a_version_should_return_its_fixed_issues
    version = Version.find(2)
    assert version.fixed_issues.any?
    assert_equal version.fixed_issues.to_a.sort, Issue.fixed_version(version).to_a.sort
  end

  def test_fixed_version_scope_with_empty_array_should_return_no_result
    assert_equal 0, Issue.fixed_version([]).count
  end

  def test_assigned_to_scope_should_return_issues_assigned_to_the_user
    user = User.generate!
    issue = Issue.generate!
    Issue.where(:id => issue.id).update_all :assigned_to_id => user.id
    assert_equal [issue], Issue.assigned_to(user).to_a
  end

  def test_assigned_to_scope_should_return_issues_assigned_to_the_user_groups
    group = Group.generate!
    user = User.generate!
    group.users << user
    issue = Issue.generate!
    Issue.where(:id => issue.id).update_all :assigned_to_id => group.id
    assert_equal [issue], Issue.assigned_to(user).to_a
  end

  def test_issue_should_be_readonly_on_closed_project
    issue = Issue.find(1)
    user = User.find(1)

    assert_equal true, issue.visible?(user)
    assert_equal true, issue.editable?(user)
    assert_equal true, issue.deletable?(user)

    issue.project.close
    issue.reload

    assert_equal true, issue.visible?(user)
    assert_equal false, issue.editable?(user)
    assert_equal false, issue.deletable?(user)
  end

  def test_issue_should_editable_by_author
    Role.all.each do |r|
      r.remove_permission! :edit_issues
      r.add_permission! :edit_own_issues
    end

    issue = Issue.find(1)
    user = User.find_by_login('jsmith')

    # author
    assert_equal user, issue.author
    assert_equal true, issue.attributes_editable?(user)

    # not author
    assert_equal false, issue.attributes_editable?(User.find_by_login('dlopper'))
  end

  def test_errors_full_messages_should_include_custom_fields_errors
    field = IssueCustomField.find_by_name('Database')

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 1,
                      :status_id => 1, :subject => 'test_create',
                      :description => 'IssueTest#test_create_with_required_custom_field')
    assert issue.available_custom_fields.include?(field)
    # Invalid value
    issue.custom_field_values = {field.id => 'SQLServer'}

    assert !issue.valid?
    assert_equal 1, issue.errors.full_messages.size
    assert_equal "Database #{I18n.translate('activerecord.errors.messages.inclusion')}",
                 issue.errors.full_messages.first
  end

  def test_update_issue_with_required_custom_field
    field = IssueCustomField.find_by_name('Database')
    field.update!(:is_required => true)

    issue = Issue.find(1)
    assert_nil issue.custom_value_for(field)
    assert issue.available_custom_fields.include?(field)
    # No change to custom values, issue can be saved
    assert issue.save
    # Blank value
    issue.custom_field_values = {field.id => ''}
    assert !issue.save
    # Valid value
    issue.custom_field_values = {field.id => 'PostgreSQL'}
    assert issue.save
    issue.reload
    assert_equal 'PostgreSQL', issue.custom_value_for(field).value
  end

  def test_should_not_update_attributes_if_custom_fields_validation_fails
    issue = Issue.find(1)
    field = IssueCustomField.find_by_name('Database')
    assert issue.available_custom_fields.include?(field)

    issue.custom_field_values = {field.id => 'Invalid'}
    issue.subject = 'Should be not be saved'
    assert !issue.save

    issue.reload
    assert_equal "Cannot print recipes", issue.subject
  end

  def test_should_not_recreate_custom_values_objects_on_update
    field = IssueCustomField.find_by_name('Database')

    issue = Issue.find(1)
    issue.custom_field_values = {field.id => 'PostgreSQL'}
    assert issue.save
    custom_value = issue.custom_value_for(field)
    issue.reload
    issue.custom_field_values = {field.id => 'MySQL'}
    assert issue.save
    issue.reload
    assert_equal custom_value.id, issue.custom_value_for(field).id
  end

  def test_setting_project_should_set_version_to_default_version
    version = Version.generate!(:project_id => 1)
    Project.find(1).update!(:default_version_id => version.id)

    issue = Issue.new(:project_id => 1)
    assert_equal version, issue.fixed_version
  end

  def test_default_assigned_to_based_on_category_should_be_set_on_create
    user = User.find(3)
    category = IssueCategory.create!(:project_id => 1, :name => 'With default assignee', :assigned_to_id => 3)

    issue = Issue.generate!(:project_id => 1, :category_id => category.id)
    assert_equal user, issue.assigned_to
  end

  def test_default_assigned_to_based_on_project_should_be_set_on_create
    user = User.find(3)
    Project.find(1).update!(:default_assigned_to_id => user.id)

    issue = Issue.generate!(:project_id => 1)
    assert_equal user, issue.assigned_to
  end

  def test_default_assigned_to_with_required_assignee_should_validate
    category = IssueCategory.create!(:project_id => 1, :name => 'With default assignee', :assigned_to_id => 3)
    Issue.any_instance.stubs(:required_attribute_names).returns(['assigned_to_id'])

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 1, :subject => 'Default')
    assert !issue.save
    assert issue.errors['assigned_to_id'].present?

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 1, :subject => 'Default', :category_id => category.id)
    assert_save issue
  end

  def test_should_not_update_custom_fields_on_changing_tracker_with_different_custom_fields
    issue = Issue.create!(:project_id => 1, :tracker_id => 1, :author_id => 1,
                          :status_id => 1, :subject => 'Test',
                          :custom_field_values => {'2' => 'Test'})
    assert !Tracker.find(2).custom_field_ids.include?(2)

    issue = Issue.find(issue.id)
    issue.attributes = {:tracker_id => 2, :custom_field_values => {'1' => ''}}

    issue = Issue.find(issue.id)
    custom_value = issue.custom_value_for(2)
    assert_not_nil custom_value
    assert_equal 'Test', custom_value.value
  end

  def test_assigning_tracker_id_should_reload_custom_fields_values
    issue = Issue.new(:project => Project.find(1))
    assert issue.custom_field_values.empty?
    issue.tracker_id = 1
    assert issue.custom_field_values.any?
  end

  def test_assigning_attributes_should_assign_project_and_tracker_first
    seq = sequence('seq')
    issue = Issue.new
    issue.expects(:project_id=).in_sequence(seq)
    issue.expects(:tracker_id=).in_sequence(seq)
    issue.expects(:subject=).in_sequence(seq)
    assert_raise Exception do
      issue.attributes = {:subject => 'Test'}
    end
    assert_nothing_raised do
      issue.attributes = {:tracker_id => 2, :project_id => 1, :subject => 'Test'}
    end
  end

  def test_assigning_tracker_and_custom_fields_should_assign_custom_fields
    attributes = ActiveSupport::OrderedHash.new
    attributes['custom_field_values'] = {'1' => 'MySQL'}
    attributes['tracker_id'] = '1'
    issue = Issue.new(:project => Project.find(1))
    issue.attributes = attributes
    assert_equal 'MySQL', issue.custom_field_value(1)
  end

  def test_changing_tracker_should_clear_disabled_core_fields
    tracker = Tracker.find(2)
    tracker.core_fields = tracker.core_fields - %w(due_date)
    tracker.save!

    issue = Issue.generate!(:tracker_id => 1, :start_date => Date.today, :due_date => Date.today)
    issue.save!

    issue.tracker_id = 2
    issue.save!
    assert_not_nil issue.start_date
    assert_nil issue.due_date
  end

  def test_attribute_cleared_on_tracker_change_should_be_journalized
    CustomField.delete_all
    tracker = Tracker.find(2)
    tracker.core_fields = tracker.core_fields - %w(due_date)
    tracker.save!

    issue = Issue.generate!(:tracker_id => 1, :due_date => Date.today)
    issue.save!

    assert_difference 'Journal.count' do
      issue.init_journal User.find(1)
      issue.tracker_id = 2
      issue.save!
      assert_nil issue.due_date
    end
    journal = Journal.order('id DESC').first
    details = journal.details.select {|d| d.prop_key == 'due_date'}
    assert_equal 1, details.count
  end

  def test_reload_should_reload_custom_field_values
    issue = Issue.generate!
    issue.custom_field_values = {'2' => 'Foo'}
    issue.save!

    issue = Issue.order('id desc').first
    assert_equal 'Foo', issue.custom_field_value(2)

    issue.custom_field_values = {'2' => 'Bar'}
    assert_equal 'Bar', issue.custom_field_value(2)

    issue.reload
    assert_equal 'Foo', issue.custom_field_value(2)
  end

  def test_should_update_issue_with_disabled_tracker
    p = Project.find(1)
    issue = Issue.find(1)

    p.trackers.delete(issue.tracker)
    assert !p.trackers.include?(issue.tracker)

    issue.reload
    issue.subject = 'New subject'
    assert issue.save
  end

  def test_should_not_set_a_disabled_tracker
    p = Project.find(1)
    p.trackers.delete(Tracker.find(2))

    issue = Issue.find(1)
    issue.tracker_id = 2
    issue.subject = 'New subject'
    assert !issue.save
    assert_not_equal [], issue.errors[:tracker_id]
  end

  def test_category_based_assignment
    issue = Issue.create(:project_id => 1, :tracker_id => 1, :author_id => 3,
                         :status_id => 1, :priority => IssuePriority.all.first,
                         :subject => 'Assignment test',
                         :description => 'Assignment test', :category_id => 1)
    assert_equal IssueCategory.find(1).assigned_to, issue.assigned_to
  end

  def test_new_statuses_allowed_to
    WorkflowTransition.delete_all
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1,
                               :old_status_id => 1, :new_status_id => 2,
                               :author => false, :assignee => false)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1,
                               :old_status_id => 1, :new_status_id => 3,
                               :author => true, :assignee => false)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1,
                               :old_status_id => 1, :new_status_id => 4,
                               :author => false, :assignee => true)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1,
                               :old_status_id => 1, :new_status_id => 5,
                               :author => true, :assignee => true)
    status = IssueStatus.find(1)
    role = Role.find(1)
    tracker = Tracker.find(1)
    user = User.find(2)

    issue = Issue.generate!(:tracker => tracker, :status => status,
                            :project_id => 1, :author_id => 1)
    assert_equal [1, 2], issue.new_statuses_allowed_to(user).map(&:id)

    issue = Issue.generate!(:tracker => tracker, :status => status,
                            :project_id => 1, :author => user)
    assert_equal [1, 2, 3, 5], issue.new_statuses_allowed_to(user).map(&:id)

    issue = Issue.generate!(:tracker => tracker, :status => status,
                            :project_id => 1, :author_id => 1,
                            :assigned_to => user)
    assert_equal [1, 2, 4, 5], issue.new_statuses_allowed_to(user).map(&:id)

    issue = Issue.generate!(:tracker => tracker, :status => status,
                            :project_id => 1, :author => user,
                            :assigned_to => user)
    assert_equal [1, 2, 3, 4, 5], issue.new_statuses_allowed_to(user).map(&:id)
  end

  def test_new_statuses_allowed_to_should_consider_group_assignment
    WorkflowTransition.delete_all
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1,
                               :old_status_id => 1, :new_status_id => 4,
                               :author => false, :assignee => true)
    group = Group.generate!
    Member.create!(:project_id => 1, :principal => group, :role_ids => [1])

    user = User.find(2)
    group.users << user

    with_settings :issue_group_assignment => '1' do
      issue = Issue.generate!(:author_id => 1, :assigned_to => group)
      assert_include 4, issue.new_statuses_allowed_to(user).map(&:id)
    end
  end

  def test_new_statuses_allowed_to_should_return_all_transitions_for_admin
    admin = User.find(1)
    issue = Issue.find(1)
    assert !admin.member_of?(issue.project)
    expected_statuses = [issue.status] +
                            WorkflowTransition.where(:old_status_id => issue.status_id).
                                map(&:new_status).uniq.sort
    assert_equal expected_statuses, issue.new_statuses_allowed_to(admin)
  end

  def test_new_statuses_allowed_to_should_return_allowed_statuses_when_copying
    Tracker.find(1).generate_transitions! :role_id => 1, :clear => true, 0 => [1, 3]

    orig = Issue.generate!(:project_id => 1, :tracker_id => 1, :status_id => 4)
    issue = orig.copy
    assert_equal [1, 3], issue.new_statuses_allowed_to(User.find(2)).map(&:id)
    assert_equal 1, issue.status_id
  end

  def test_safe_attributes_names_should_be_updated_when_changing_project
    issue = Issue.new
    with_current_user(User.find(2)) do
      assert_not_include 'watcher_user_ids', issue.safe_attribute_names

      issue.project_id = 1
      assert_include 'watcher_user_ids', issue.safe_attribute_names
    end
  end

  def test_safe_attributes_names_should_not_include_disabled_field
    tracker = Tracker.new(:core_fields => %w(assigned_to_id fixed_version_id))

    issue = Issue.new(:tracker => tracker)
    assert_include 'tracker_id', issue.safe_attribute_names
    assert_include 'status_id', issue.safe_attribute_names
    assert_include 'subject', issue.safe_attribute_names
    assert_include 'custom_field_values', issue.safe_attribute_names
    assert_include 'custom_fields', issue.safe_attribute_names
    assert_include 'lock_version', issue.safe_attribute_names

    tracker.core_fields.each do |field|
      assert_include field, issue.safe_attribute_names
    end

    tracker.disabled_core_fields.each do |field|
      assert_not_include field, issue.safe_attribute_names
    end
  end

  def test_safe_attributes_should_ignore_disabled_fields
    tracker = Tracker.find(1)
    tracker.core_fields = %w(assigned_to_id due_date)
    tracker.save!

    issue = Issue.new(:tracker => tracker)
    issue.safe_attributes = {'start_date' => '2012-07-14', 'due_date' => '2012-07-14'}
    assert_nil issue.start_date
    assert_equal Date.parse('2012-07-14'), issue.due_date
  end

  def test_safe_attributes_notes_should_check_add_issue_notes_permission
    # With add_issue_notes permission
    user = User.find(2)
    issue = Issue.new(:project => Project.find(1))
    issue.init_journal(user)
    issue.send :safe_attributes=, {'notes' => 'note'}, user
    assert_equal 'note', issue.notes

    # Without add_issue_notes permission
    Role.find(1).remove_permission!(:add_issue_notes)
    issue = Issue.new(:project => Project.find(1))
    user.reload
    issue.init_journal(user)
    issue.send :safe_attributes=, {'notes' => 'note'}, user
    assert_equal '', issue.notes
  end

  def test_safe_attributes_should_accept_target_tracker_enabled_fields
    source = Tracker.find(1)
    source.core_fields = []
    source.save!
    target = Tracker.find(2)
    target.core_fields = %w(assigned_to_id due_date)
    target.save!
    user = User.find(2)

    issue = Issue.new(:project => Project.find(1), :tracker => source)
    issue.send :safe_attributes=, {'tracker_id' => 2, 'due_date' => '2012-07-14'}, user
    assert_equal target, issue.tracker
    assert_equal Date.parse('2012-07-14'), issue.due_date
  end

  def test_safe_attributes_should_not_include_readonly_fields
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role_id => 1, :field_name => 'due_date',
                               :rule => 'readonly')
    user = User.find(2)

    issue = Issue.new(:project_id => 1, :tracker_id => 1)
    assert_equal %w(due_date), issue.read_only_attribute_names(user)
    assert_not_include 'due_date', issue.safe_attribute_names(user)

    issue.send :safe_attributes=, {'start_date' => '2012-07-14', 'due_date' => '2012-07-14'}, user
    assert_equal Date.parse('2012-07-14'), issue.start_date
    assert_nil issue.due_date
  end

  def test_safe_attributes_should_not_include_readonly_custom_fields
    cf1 = IssueCustomField.create!(:name => 'Writable field',
                                   :field_format => 'string',
                                   :is_for_all => true, :tracker_ids => [1])
    cf2 = IssueCustomField.create!(:name => 'Readonly field',
                                   :field_format => 'string',
                                   :is_for_all => true, :tracker_ids => [1])
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role_id => 1, :field_name => cf2.id.to_s,
                               :rule => 'readonly')
    user = User.find(2)
    issue = Issue.new(:project_id => 1, :tracker_id => 1)
    assert_equal [cf2.id.to_s], issue.read_only_attribute_names(user)
    assert_not_include cf2.id.to_s, issue.safe_attribute_names(user)

    issue.send(
      :safe_attributes=,
      {
        'custom_field_values' =>
          {
            cf1.id.to_s => 'value1',
            cf2.id.to_s => 'value2'
          }
      },
      user
    )
    assert_equal 'value1', issue.custom_field_value(cf1)
    assert_nil issue.custom_field_value(cf2)

    issue.send(
      :safe_attributes=,
      {
        'custom_fields' =>
          [
            {'id' => cf1.id.to_s, 'value' => 'valuea'},
            {'id' => cf2.id.to_s, 'value' => 'valueb'}
          ]
      }, user
    )
    assert_equal 'valuea', issue.custom_field_value(cf1)
    assert_nil issue.custom_field_value(cf2)
  end

  def test_editable_custom_field_values_should_return_non_readonly_custom_values
    cf1 = IssueCustomField.create!(:name => 'Writable field', :field_format => 'string',
                                   :is_for_all => true, :tracker_ids => [1, 2])
    cf2 = IssueCustomField.create!(:name => 'Readonly field', :field_format => 'string',
                                   :is_for_all => true, :tracker_ids => [1, 2])
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 1,
                               :field_name => cf2.id.to_s, :rule => 'readonly')
    user = User.find(2)

    issue = Issue.new(:project_id => 1, :tracker_id => 1)
    values = issue.editable_custom_field_values(user)
    assert values.detect {|value| value.custom_field == cf1}
    assert_nil values.detect {|value| value.custom_field == cf2}

    issue.tracker_id = 2
    values = issue.editable_custom_field_values(user)
    assert values.detect {|value| value.custom_field == cf1}
    assert values.detect {|value| value.custom_field == cf2}
  end

  def test_editable_custom_fields_should_return_custom_field_that_is_enabled_for_the_role_only
    enabled_cf =
      IssueCustomField.generate!(:is_for_all => true, :tracker_ids => [1],
                                 :visible => false, :role_ids => [1, 2])
    disabled_cf =
      IssueCustomField.generate!(:is_for_all => true, :tracker_ids => [1],
                                 :visible => false, :role_ids => [2])
    user = User.find(2)
    issue = Issue.new(:project_id => 1, :tracker_id => 1)

    assert_include enabled_cf, issue.editable_custom_fields(user)
    assert_not_include disabled_cf, issue.editable_custom_fields(user)
  end

  def test_safe_attributes_should_accept_target_tracker_writable_fields
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role_id => 1, :field_name => 'due_date',
                               :rule => 'readonly')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 2,
                               :role_id => 1, :field_name => 'start_date',
                               :rule => 'readonly')
    user = User.find(2)

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1)

    issue.send :safe_attributes=, {'start_date' => '2012-07-12',
                                   'due_date' => '2012-07-14'}, user
    assert_equal Date.parse('2012-07-12'), issue.start_date
    assert_nil issue.due_date

    issue.send :safe_attributes=, {'start_date' => '2012-07-15',
                                   'due_date' => '2012-07-16',
                                   'tracker_id' => 2}, user
    assert_equal Date.parse('2012-07-12'), issue.start_date
    assert_equal Date.parse('2012-07-16'), issue.due_date
  end

  def test_safe_attributes_should_accept_target_status_writable_fields
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role_id => 1, :field_name => 'due_date',
                               :rule => 'readonly')
    WorkflowPermission.create!(:old_status_id => 2, :tracker_id => 1,
                               :role_id => 1, :field_name => 'start_date',
                               :rule => 'readonly')
    user = User.find(2)

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1)

    issue.send(:safe_attributes=,
               {'start_date' => '2012-07-12',
                'due_date' => '2012-07-14'},
               user)
    assert_equal Date.parse('2012-07-12'), issue.start_date
    assert_nil issue.due_date

    issue.send(:safe_attributes=,
               {'start_date' => '2012-07-15',
                'due_date' => '2012-07-16',
                'status_id' => 2},
               user)
    assert_equal Date.parse('2012-07-12'), issue.start_date
    assert_equal Date.parse('2012-07-16'), issue.due_date
  end

  def test_required_attributes_should_be_validated
    cf = IssueCustomField.create!(:name => 'Foo', :field_format => 'string',
                                  :is_for_all => true, :tracker_ids => [1, 2])

    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role_id => 1, :field_name => 'due_date',
                               :rule => 'required')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role_id => 1, :field_name => 'category_id',
                               :rule => 'required')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role_id => 1, :field_name => cf.id.to_s,
                               :rule => 'required')

    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 2,
                               :role_id => 1, :field_name => 'start_date',
                               :rule => 'required')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 2,
                               :role_id => 1, :field_name => cf.id.to_s,
                               :rule => 'required')
    user = User.find(2)

    issue = Issue.new(:project_id => 1, :tracker_id => 1,
                      :status_id => 1, :subject => 'Required fields',
                      :author => user)
    assert_equal [cf.id.to_s, "category_id", "due_date"],
                 issue.required_attribute_names(user).sort
    assert !issue.save, "Issue was saved"
    assert_equal ["Category cannot be blank", "Due date cannot be blank", "Foo cannot be blank"],
                 issue.errors.full_messages.sort

    issue.tracker_id = 2
    assert_equal [cf.id.to_s, "start_date"], issue.required_attribute_names(user).sort
    assert !issue.save, "Issue was saved"
    assert_equal ["Foo cannot be blank", "Start date cannot be blank"],
                 issue.errors.full_messages.sort

    issue.start_date = Date.today
    issue.custom_field_values = {cf.id.to_s => 'bar'}
    assert issue.save
  end

  def test_required_attribute_that_is_disabled_for_the_tracker_should_not_be_required
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role_id => 1, :field_name => 'start_date',
                               :rule => 'required')
    user = User.find(2)

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1,
                      :subject => 'Required fields', :author => user)
    assert !issue.save
    assert_include "Start date cannot be blank", issue.errors.full_messages

    tracker = Tracker.find(1)
    tracker.core_fields -= %w(start_date)
    tracker.save!
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1,
                      :subject => 'Required fields', :author => user)
    assert issue.save
  end

  def test_category_should_not_be_required_if_project_has_no_categories
    Project.find(1).issue_categories.delete_all
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role_id => 1, :field_name => 'category_id',
                               :rule => 'required')
    user = User.find(2)

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1,
                      :subject => 'Required fields', :author => user)
    assert_save issue
  end

  def test_fixed_version_should_not_be_required_no_assignable_versions
    Version.delete_all
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role_id => 1, :field_name => 'fixed_version_id',
                               :rule => 'required')
    user = User.find(2)

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1,
                      :subject => 'Required fields', :author => user)
    assert_save issue
  end

  def test_required_custom_field_that_is_not_visible_for_the_user_should_not_be_required
    CustomField.destroy_all
    field = IssueCustomField.generate!(:is_required => true, :visible => false,
                                       :role_ids => [1], :trackers => Tracker.all,
                                       :is_for_all => true)
    user = User.generate!
    User.add_to_project(user, Project.find(1), Role.find(2))

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1,
                      :subject => 'Required fields', :author => user)
    assert_save issue
  end

  def test_required_custom_field_that_is_visible_for_the_user_should_be_required
    CustomField.destroy_all
    field = IssueCustomField.generate!(:is_required => true, :visible => false,
                                       :role_ids => [1], :trackers => Tracker.all,
                                       :is_for_all => true)
    user = User.generate!
    User.add_to_project(user, Project.find(1), Role.find(1))

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1,
                      :subject => 'Required fields', :author => user)
    assert !issue.save
    assert_include "#{field.name} cannot be blank", issue.errors.full_messages
  end

  def test_required_attribute_names_for_multiple_roles_should_intersect_rules
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role_id => 1, :field_name => 'due_date',
                               :rule => 'required')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role_id => 1, :field_name => 'start_date',
                               :rule => 'required')
    user = User.find(2)
    member = Member.find(1)
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1)

    assert_equal %w(due_date start_date), issue.required_attribute_names(user).sort

    member.role_ids = [1, 2]
    member.save!
    assert_equal [], issue.required_attribute_names(user.reload)

    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role_id => 2, :field_name => 'due_date',
                               :rule => 'required')
    assert_equal %w(due_date), issue.required_attribute_names(user)

    member.role_ids = [1, 2, 3]
    member.save!
    assert_equal [], issue.required_attribute_names(user.reload)

    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role_id => 3, :field_name => 'due_date',
                               :rule => 'readonly')
    # required + readonly => required
    assert_equal %w(due_date), issue.required_attribute_names(user)
  end

  def test_read_only_attribute_names_for_multiple_roles_should_intersect_rules
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role_id => 1, :field_name => 'due_date',
                               :rule => 'readonly')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role_id => 1, :field_name => 'start_date',
                               :rule => 'readonly')
    user = User.find(2)
    member = Member.find(1)
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1)

    assert_equal %w(due_date start_date), issue.read_only_attribute_names(user).sort

    member.role_ids = [1, 2]
    member.save!
    assert_equal [], issue.read_only_attribute_names(user.reload)

    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                              :role_id => 2, :field_name => 'due_date',
                              :rule => 'readonly')
    assert_equal %w(due_date), issue.read_only_attribute_names(user)
  end

  # A field that is not visible by role 2 and readonly by role 1 should be readonly for user with role 1 and 2
  def test_read_only_attribute_names_should_include_custom_fields_that_combine_readonly_and_not_visible_for_roles
    field = IssueCustomField.generate!(
      :is_for_all => true, :trackers => Tracker.all, :visible => false, :role_ids => [1]
    )
    WorkflowPermission.delete_all
    WorkflowPermission.create!(
      :old_status_id => 1, :tracker_id => 1, :role_id => 1, :field_name => field.id, :rule => 'readonly'
    )
    user = User.generate!
    project = Project.find(1)
    User.add_to_project(user, project, Role.where(:id => [1, 2]))

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1)
    assert_equal [field.id.to_s], issue.read_only_attribute_names(user)
  end

  def test_workflow_rules_should_ignore_roles_without_issue_permissions
    role = Role.generate! :permissions => [:view_issues, :edit_issues]
    ignored_role = Role.generate! :permissions => [:view_issues]

    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role => role, :field_name => 'due_date',
                               :rule => 'required')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role => role, :field_name => 'start_date',
                               :rule => 'readonly')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role => role, :field_name => 'done_ratio',
                               :rule => 'readonly')
    user = User.generate!
    User.add_to_project user, Project.find(1), [role, ignored_role]

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1)

    assert_equal %w(due_date), issue.required_attribute_names(user)
    assert_equal %w(done_ratio start_date), issue.read_only_attribute_names(user).sort
  end

  def test_workflow_rules_should_work_for_member_with_duplicate_role
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role_id => 1, :field_name => 'due_date',
                               :rule => 'required')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1,
                               :role_id => 1, :field_name => 'start_date',
                               :rule => 'readonly')

    user = User.generate!
    m = Member.new(:user_id => user.id, :project_id => 1)
    m.member_roles.build(:role_id => 1)
    m.member_roles.build(:role_id => 1)
    m.save!

    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1)

    assert_equal %w(due_date), issue.required_attribute_names(user)
    assert_equal %w(start_date), issue.read_only_attribute_names(user)
  end

  def test_copy
    issue = Issue.new.copy_from(1)
    assert issue.copy?
    assert issue.save
    issue.reload
    orig = Issue.find(1)
    assert_equal orig.subject, issue.subject
    assert_equal orig.tracker, issue.tracker
    assert_equal "125", issue.custom_value_for(2).value
  end

  def test_copy_to_another_project_should_clear_assignee_if_not_valid
    issue = Issue.generate!(:project_id => 1, :assigned_to_id => 2)
    project = Project.generate!

    issue = Issue.new.copy_from(1)
    issue.project = project
    assert_nil issue.assigned_to
  end

  def test_copy_with_keep_status_should_copy_status
    orig = Issue.find(8)
    assert orig.status != orig.default_status

    issue = Issue.new.copy_from(orig, :keep_status => true)
    assert issue.save
    issue.reload
    assert_equal orig.status, issue.status
  end

  def test_copy_should_add_relation_with_copied_issue
    copied = Issue.find(1)
    issue = Issue.new.copy_from(copied)
    assert issue.save
    issue.reload

    assert_equal 1, issue.relations.size
    relation = issue.relations.first
    assert_equal 'copied_to', relation.relation_type
    assert_equal copied, relation.issue_from
    assert_equal issue, relation.issue_to
  end

  def test_copy_should_copy_subtasks
    issue = Issue.generate_with_descendants!

    copy = issue.reload.copy
    copy.author = User.find(7)
    assert_difference 'Issue.count', 1+issue.descendants.count do
      assert copy.save
    end
    copy.reload
    assert_equal %w(Child1 Child2), copy.children.map(&:subject).sort
    child_copy = copy.children.detect {|c| c.subject == 'Child1'}
    assert_equal %w(Child11), child_copy.children.map(&:subject).sort
    assert_equal copy.author, child_copy.author
  end

  def test_copy_as_a_child_of_copied_issue_should_not_copy_itself
    parent = Issue.generate!
    child1 = Issue.generate!(:parent_issue_id => parent.id, :subject => 'Child 1')
    child2 = Issue.generate!(:parent_issue_id => parent.id, :subject => 'Child 2')

    copy = parent.reload.copy
    copy.parent_issue_id = parent.id
    copy.author = User.find(7)
    assert_difference 'Issue.count', 3 do
      assert copy.save
    end
    parent.reload
    copy.reload
    assert_equal parent, copy.parent
    assert_equal 3, parent.children.count
    assert_equal 5, parent.descendants.count
    assert_equal 2, copy.children.count
    assert_equal 2, copy.descendants.count
  end

  def test_copy_as_a_descendant_of_copied_issue_should_not_copy_itself
    parent = Issue.generate!
    child1 = Issue.generate!(:parent_issue_id => parent.id, :subject => 'Child 1')
    child2 = Issue.generate!(:parent_issue_id => parent.id, :subject => 'Child 2')

    copy = parent.reload.copy
    copy.parent_issue_id = child1.id
    copy.author = User.find(7)
    assert_difference 'Issue.count', 3 do
      assert copy.save
    end
    parent.reload
    child1.reload
    copy.reload
    assert_equal child1, copy.parent
    assert_equal 2, parent.children.count
    assert_equal 5, parent.descendants.count
    assert_equal 1, child1.children.count
    assert_equal 3, child1.descendants.count
    assert_equal 2, copy.children.count
    assert_equal 2, copy.descendants.count
  end

  def test_copy_should_copy_subtasks_to_target_project
    issue = Issue.generate_with_descendants!

    copy = issue.copy(:project_id => 3)
    assert_difference 'Issue.count', 1+issue.descendants.count do
      assert copy.save
    end
    assert_equal [3], copy.reload.descendants.map(&:project_id).uniq
  end

  def test_copy_should_not_copy_subtasks_twice_when_saving_twice
    issue = Issue.generate_with_descendants!

    copy = issue.reload.copy
    assert_difference 'Issue.count', 1+issue.descendants.count do
      assert copy.save
      assert copy.reload.save
    end
  end

  def test_copy_should_clear_closed_on
    copied_open = Issue.find(8).copy(:status_id => 1)
    assert copied_open.save
    assert_nil copied_open.closed_on

    copied_closed = Issue.find(8).copy({}, :keep_status => 1)
    assert copied_closed.save
    assert_not_nil copied_closed.closed_on
  end

  def test_copy_should_not_copy_locked_watchers
    user = User.find(2)
    user2 = User.find(3)
    issue = Issue.find(8)

    Watcher.create!(:user => user, :watchable => issue)
    Watcher.create!(:user => user2, :watchable => issue)

    user2.status = User::STATUS_LOCKED
    user2.save!

    issue = Issue.new.copy_from(8)

    assert issue.save
    assert issue.watched_by?(user)
    assert !issue.watched_by?(user2)
  end

  def test_copy_should_clear_subtasks_target_version_if_locked_or_closed
    version = Version.new(:project => Project.find(1), :name => '2.1')
    version.save!

    parent = Issue.generate!
    child1 = Issue.generate!(:parent_issue_id => parent.id, :subject => 'Child 1', :fixed_version_id => 3)
    child2 = Issue.generate!(:parent_issue_id => parent.id, :subject => 'Child 2', :fixed_version_id => version.id)

    version.status = 'locked'
    version.save!

    copy = parent.reload.copy

    assert_difference 'Issue.count', 3 do
      assert copy.save
    end

    assert_equal [3, nil], copy.children.map(&:fixed_version_id)
  end

  def test_copy_should_clear_subtasks_assignee_if_is_locked
    user = User.find(2)

    parent = Issue.generate!
    child1 = Issue.generate!(:parent_issue_id => parent.id, :subject => 'Child 1', :assigned_to_id => 3)
    child2 = Issue.generate!(:parent_issue_id => parent.id, :subject => 'Child 2', :assigned_to_id => user.id)

    user.status = User::STATUS_LOCKED
    user.save!

    copy = parent.reload.copy

    assert_difference 'Issue.count', 3 do
      assert copy.save
    end

    assert_equal [3, nil], copy.children.map(&:assigned_to_id)
  end

  def test_copy_should_not_add_attachments_to_journal
    set_tmp_attachments_directory
    issue = Issue.generate!
    copy = Issue.new
    copy.init_journal User.find(1)
    copy.copy_from issue

    copy.project = issue.project
    copy.save_attachments(
      { 'p0' => {'file' => mock_file_with_options(:original_filename => 'upload')} }
    )
    assert copy.save
    assert j = copy.journals.last
    assert_equal 1, j.details.size
    assert_equal 'relation', j.details[0].property
  end

  def test_should_not_call_after_project_change_on_creation
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :status_id => 1,
                      :subject => 'Test', :author_id => 1)
    issue.expects(:after_project_change).never
    issue.save!
  end

  def test_should_not_call_after_project_change_on_update
    issue = Issue.find(1)
    issue.project = Project.find(1)
    issue.subject = 'No project change'
    issue.expects(:after_project_change).never
    issue.save!
  end

  def test_should_call_after_project_change_on_project_change
    issue = Issue.find(1)
    issue.project = Project.find(2)
    issue.expects(:after_project_change).once
    issue.save!
  end

  def test_adding_journal_should_update_timestamp
    issue = Issue.find(1)
    updated_on_was = issue.updated_on

    issue.init_journal(User.first, "Adding notes")
    assert_difference 'Journal.count' do
      assert issue.save
    end
    issue.reload

    assert_not_equal updated_on_was, issue.updated_on
  end

  def test_should_close_duplicates
    # Create 3 issues
    issue1 = Issue.generate!
    issue2 = Issue.generate!
    issue3 = Issue.generate!

    # 2 is a dupe of 1
    IssueRelation.create!(:issue_from => issue2, :issue_to => issue1,
                          :relation_type => IssueRelation::TYPE_DUPLICATES)
    # And 3 is a dupe of 2
    IssueRelation.create!(:issue_from => issue3, :issue_to => issue2,
                          :relation_type => IssueRelation::TYPE_DUPLICATES)
    # And 3 is a dupe of 1 (circular duplicates)
    IssueRelation.create!(:issue_from => issue3, :issue_to => issue1,
                          :relation_type => IssueRelation::TYPE_DUPLICATES)

    assert issue1.reload.duplicates.include?(issue2)

    # Closing issue 1
    issue1.init_journal(User.first, "Closing issue1")
    issue1.status = IssueStatus.where(:is_closed => true).first
    assert issue1.save
    # 2 and 3 should be also closed
    assert issue2.reload.closed?
    assert issue3.reload.closed?
  end

  def test_should_not_close_duplicate_when_disabled
    issue = Issue.generate!
    duplicate = Issue.generate!

    IssueRelation.create!(:issue_from => duplicate, :issue_to => issue,
                          :relation_type => IssueRelation::TYPE_DUPLICATES)
    assert issue.reload.duplicates.include?(duplicate)

    with_settings :close_duplicate_issues => '0' do
      issue.init_journal(User.first, "Closing issue")
      issue.status = IssueStatus.where(:is_closed => true).first
      issue.save
    end

    assert !duplicate.reload.closed?
  end

  def test_should_close_duplicates_with_private_notes
    issue = Issue.generate!
    duplicate = Issue.generate!
    IssueRelation.create!(:issue_from => duplicate, :issue_to => issue,
                          :relation_type => IssueRelation::TYPE_DUPLICATES)
    assert issue.reload.duplicates.include?(duplicate)

    # Closing issue with private notes
    issue.init_journal(User.first, "Private notes")
    issue.private_notes = true
    issue.status = IssueStatus.where(:is_closed => true).first
    assert_save issue

    duplicate.reload
    assert journal = duplicate.journals.detect {|journal| journal.notes == "Private notes"}
    assert_equal true, journal.private_notes
  end

  def test_should_not_close_duplicated_issue
    issue1 = Issue.generate!
    issue2 = Issue.generate!

    # 2 is a dupe of 1
    IssueRelation.create(:issue_from => issue2, :issue_to => issue1,
                         :relation_type => IssueRelation::TYPE_DUPLICATES)
    # 2 is a dup of 1 but 1 is not a duplicate of 2
    assert !issue2.reload.duplicates.include?(issue1)

    # Closing issue 2
    issue2.init_journal(User.first, "Closing issue2")
    issue2.status = IssueStatus.where(:is_closed => true).first
    assert issue2.save
    # 1 should not be also closed
    assert !issue1.reload.closed?
  end

  def test_assignable_versions
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 1,
                      :status_id => 1, :fixed_version_id => 1,
                      :subject => 'New issue')
    assert_equal ['open'], issue.assignable_versions.collect(&:status).uniq
  end

  def test_should_not_be_able_to_set_an_invalid_version_id
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 1,
                      :status_id => 1, :fixed_version_id => 424242,
                      :subject => 'New issue')
    assert !issue.save
    assert_not_equal [], issue.errors[:fixed_version_id]
  end

  def test_should_not_be_able_to_assign_a_new_issue_to_a_closed_version
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 1,
                      :status_id => 1, :fixed_version_id => 1,
                      :subject => 'New issue')
    assert !issue.save
    assert_not_equal [], issue.errors[:fixed_version_id]
  end

  def test_should_not_be_able_to_assign_a_new_issue_to_a_locked_version
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 1,
                      :status_id => 1, :fixed_version_id => 2,
                      :subject => 'New issue')
    assert !issue.save
    assert_not_equal [], issue.errors[:fixed_version_id]
  end

  def test_should_be_able_to_assign_a_new_issue_to_an_open_version
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 1,
                      :status_id => 1, :fixed_version_id => 3,
                      :subject => 'New issue')
    assert issue.save
  end

  def test_should_be_able_to_update_an_issue_assigned_to_a_closed_version
    issue = Issue.find(11)
    assert_equal 'closed', issue.fixed_version.status
    issue.subject = 'Subject changed'
    assert issue.save
  end

  def test_should_not_be_able_to_reopen_an_issue_assigned_to_a_closed_version
    issue = Issue.find(11)
    issue.status_id = 1
    assert !issue.save
    assert_not_equal [], issue.errors[:base]
  end

  def test_should_be_able_to_reopen_and_reassign_an_issue_assigned_to_a_closed_version
    issue = Issue.find(11)
    issue.status_id = 1
    issue.fixed_version_id = 3
    assert issue.save
  end

  def test_should_be_able_to_reopen_an_issue_assigned_to_a_locked_version
    issue = Issue.find(12)
    assert_equal 'locked', issue.fixed_version.status
    issue.status_id = 1
    assert issue.save
  end

  def test_should_not_be_able_to_keep_unshared_version_when_changing_project
    issue = Issue.find(2)
    assert_equal 2, issue.fixed_version_id
    issue.project_id = 3
    assert_nil issue.fixed_version_id
    issue.fixed_version_id = 2
    assert !issue.save
    assert_include 'Target version is not included in the list', issue.errors.full_messages
  end

  def test_should_keep_shared_version_when_changing_project
    Version.find(2).update! :sharing => 'tree'

    issue = Issue.find(2)
    assert_equal 2, issue.fixed_version_id
    issue.project_id = 3
    assert_equal 2, issue.fixed_version_id
    assert issue.save
  end

  def test_should_not_be_able_to_set_an_invalid_category_id
    issue = Issue.new(:project_id => 1, :tracker_id => 1, :author_id => 1,
                      :status_id => 1, :category_id => 3,
                      :subject => 'New issue')
    assert !issue.save
    assert_not_equal [], issue.errors[:category_id]
  end

  def test_allowed_target_projects_should_include_projects_with_issue_tracking_enabled
    assert_include Project.find(2), Issue.allowed_target_projects(User.find(2))
  end

  def test_allowed_target_projects_should_not_include_projects_with_issue_tracking_disabled
    Project.find(2).disable_module! :issue_tracking
    assert_not_include Project.find(2), Issue.allowed_target_projects(User.find(2))
  end

  def test_allowed_target_projects_should_not_include_projects_without_trackers
    project = Project.generate!(:tracker_ids => [])
    assert project.trackers.empty?
    assert_not_include project, Issue.allowed_target_projects(User.find(1))
  end

  def test_allowed_target_projects_for_subtask_should_not_include_invalid_projects
    User.current = User.find(1)
    issue = Issue.find(1)
    issue.parent_id = 3

    with_settings :cross_project_subtasks => 'tree' do
      # Should include only the project tree
      assert_equal [1, 3, 5], issue.allowed_target_projects_for_subtask.ids.sort
    end
  end

  def test_allowed_target_trackers_with_one_role_allowed_on_all_trackers
    user = User.generate!
    role = Role.generate!
    role.add_permission! :add_issues
    role.set_permission_trackers :add_issues, :all
    role.save!
    User.add_to_project(user, Project.find(1), role)

    assert_equal [1, 2, 3], Issue.new(:project => Project.find(1)).allowed_target_trackers(user).ids.sort
  end

  def test_allowed_target_trackers_with_one_role_allowed_on_some_trackers
    user = User.generate!
    role = Role.generate!
    role.add_permission! :add_issues
    role.set_permission_trackers :add_issues, [1, 3]
    role.save!
    User.add_to_project(user, Project.find(1), role)

    assert_equal [1, 3], Issue.new(:project => Project.find(1)).allowed_target_trackers(user).ids.sort
  end

  def test_allowed_target_trackers_with_two_roles_allowed_on_some_trackers
    user = User.generate!
    role1 = Role.generate!
    role1.add_permission! :add_issues
    role1.set_permission_trackers :add_issues, [1]
    role1.save!
    role2 = Role.generate!
    role2.add_permission! :add_issues
    role2.set_permission_trackers :add_issues, [3]
    role2.save!
    User.add_to_project(user, Project.find(1), [role1, role2])

    assert_equal [1, 3], Issue.new(:project => Project.find(1)).allowed_target_trackers(user).ids.sort
  end

  def test_allowed_target_trackers_with_two_roles_allowed_on_all_trackers_and_some_trackers
    user = User.generate!
    role1 = Role.generate!
    role1.add_permission! :add_issues
    role1.set_permission_trackers :add_issues, :all
    role1.save!
    role2 = Role.generate!
    role2.add_permission! :add_issues
    role2.set_permission_trackers :add_issues, [1, 3]
    role2.save!
    User.add_to_project(user, Project.find(1), [role1, role2])

    assert_equal [1, 2, 3], Issue.new(:project => Project.find(1)).allowed_target_trackers(user).ids.sort
  end

  def test_allowed_target_trackers_should_not_consider_roles_without_add_issues_permission
    user = User.generate!
    role1 = Role.generate!
    role1.remove_permission! :add_issues
    role1.set_permission_trackers :add_issues, :all
    role1.save!
    role2 = Role.generate!
    role2.add_permission! :add_issues
    role2.set_permission_trackers :add_issues, [1, 3]
    role2.save!
    User.add_to_project(user, Project.find(1), [role1, role2])

    assert_equal [1, 3], Issue.new(:project => Project.find(1)).allowed_target_trackers(user).ids.sort
  end

  def test_allowed_target_trackers_without_project_should_be_empty
    issue = Issue.new
    assert_nil issue.project
    assert_equal [], issue.allowed_target_trackers(User.find(2)).ids
  end

  def test_allowed_target_trackers_should_include_current_tracker
    user = User.generate!
    role = Role.generate!
    role.add_permission! :add_issues
    role.set_permission_trackers :add_issues, [3]
    role.save!
    User.add_to_project(user, Project.find(1), role)

    issue = Issue.generate!(:project => Project.find(1), :tracker => Tracker.find(1))
    assert_equal [1, 3], issue.allowed_target_trackers(user).ids.sort
  end

  def test_move_to_another_project_with_same_category
    issue = Issue.find(1)
    issue.project = Project.find(2)
    assert issue.save
    issue.reload
    assert_equal 2, issue.project_id
    # Category changes
    assert_equal 4, issue.category_id
    # Make sure time entries were move to the target project
    assert_equal 2, issue.time_entries.first.project_id
  end

  def test_move_to_another_project_without_same_category
    issue = Issue.find(2)
    issue.project = Project.find(2)
    assert issue.save
    issue.reload
    assert_equal 2, issue.project_id
    # Category cleared
    assert_nil issue.category_id
  end

  def test_move_to_another_project_should_clear_fixed_version_when_not_shared
    issue = Issue.find(1)
    issue.update!(:fixed_version_id => 3)
    issue.project = Project.find(2)
    assert issue.save
    issue.reload
    assert_equal 2, issue.project_id
    # Cleared fixed_version
    assert_nil issue.fixed_version
  end

  def test_move_to_another_project_should_keep_fixed_version_when_shared_with_the_target_project
    issue = Issue.find(1)
    issue.update!(:fixed_version_id => 4)
    issue.project = Project.find(5)
    assert issue.save
    issue.reload
    assert_equal 5, issue.project_id
    # Keep fixed_version
    assert_equal 4, issue.fixed_version_id
  end

  def test_move_to_another_project_should_clear_fixed_version_when_not_shared_with_the_target_project
    issue = Issue.find(1)
    issue.update!(:fixed_version_id => 3)
    issue.project = Project.find(5)
    assert issue.save
    issue.reload
    assert_equal 5, issue.project_id
    # Cleared fixed_version
    assert_nil issue.fixed_version
  end

  def test_move_to_another_project_should_keep_fixed_version_when_shared_systemwide
    issue = Issue.find(1)
    issue.update!(:fixed_version_id => 7)
    issue.project = Project.find(2)
    assert issue.save
    issue.reload
    assert_equal 2, issue.project_id
    # Keep fixed_version
    assert_equal 7, issue.fixed_version_id
  end

  def test_move_to_another_project_should_keep_parent_if_valid
    issue = Issue.find(1)
    issue.update! :parent_issue_id => 2
    issue.project = Project.find(3)
    assert issue.save
    issue.reload
    assert_equal 2, issue.parent_id
  end

  def test_move_to_another_project_should_clear_parent_if_not_valid
    issue = Issue.find(1)
    issue.update! :parent_issue_id => 2
    issue.project = Project.find(2)
    assert issue.save
    issue.reload
    assert_nil issue.parent_id
  end

  def test_move_to_another_project_with_disabled_tracker
    issue = Issue.find(1)
    target = Project.find(2)
    target.tracker_ids = [3]
    target.save
    issue.project = target
    assert issue.save
    issue.reload
    assert_equal 2, issue.project_id
    assert_equal 3, issue.tracker_id
  end

  def test_move_to_another_project_should_set_error_message_on_child_failure
    parent = Issue.generate!
    child = Issue.generate!(:parent_issue_id => parent.id, :tracker_id => 2)
    project = Project.generate!(:tracker_ids => [1])

    parent.reload
    parent.project_id = project.id
    assert !parent.save
    assert_include(
      "Subtask ##{child.id} could not be moved to the new project: Tracker is not included in the list",
      parent.errors[:base])
  end

  def test_copy_to_the_same_project
    issue = Issue.find(1)
    copy = issue.copy
    assert_difference 'Issue.count' do
      copy.save!
    end
    assert_kind_of Issue, copy
    assert_equal issue.project, copy.project
    assert_equal "125", copy.custom_value_for(2).value
  end

  def test_copy_to_another_project_and_tracker
    issue = Issue.find(1)
    copy = issue.copy(:project_id => 3, :tracker_id => 2)
    assert_difference 'Issue.count' do
      copy.save!
    end
    copy.reload
    assert_kind_of Issue, copy
    assert_equal Project.find(3), copy.project
    assert_equal Tracker.find(2), copy.tracker
    # Custom field #2 is not associated with target tracker
    assert_nil copy.custom_value_for(2)
  end

  test "#copy should not create a journal" do
    copy = Issue.find(1).copy({:project_id => 3, :tracker_id => 2}, :link => false)
    copy.save!
    assert_equal 0, copy.reload.journals.size
  end

  test "#copy should allow assigned_to changes" do
    user = User.generate!
    Member.create!(:project_id => 3, :principal => user, :role_ids => [1])
    copy = Issue.find(1).copy(:project_id => 3, :tracker_id => 2, :assigned_to_id => user.id)
    assert_equal user.id, copy.assigned_to_id
  end

  test "#copy should allow status changes" do
    copy = Issue.find(1).copy(:project_id => 3, :tracker_id => 2, :status_id => 2)
    assert_equal 2, copy.status_id
  end

  test "#copy should allow start date changes" do
    date = Date.today
    copy = Issue.find(1).copy(:project_id => 3, :tracker_id => 2, :start_date => date)
    assert_equal date, copy.start_date
  end

  test "#copy should allow due date changes" do
    date = Date.today
    copy = Issue.find(1).copy(:project_id => 3, :tracker_id => 2, :due_date => date)
    assert_equal date, copy.due_date
  end

  test "#copy should set current user as author" do
    User.current = User.find(9)
    copy = Issue.find(1).copy(:project_id => 3, :tracker_id => 2)
    assert_equal User.current, copy.author
  end

  test "#copy should create a journal with notes" do
    date = Date.today
    notes = "Notes added when copying"
    copy = Issue.find(1).copy({:project_id => 3, :tracker_id => 2, :start_date => date}, :link => false)
    copy.init_journal(User.current, notes)
    copy.save!

    assert_equal 1, copy.journals.size
    journal = copy.journals.first
    assert_equal 0, journal.details.size
    assert_equal notes, journal.notes
  end

  def test_valid_parent_project
    issue = Issue.find(1)
    issue_in_same_project = Issue.find(2)
    issue_in_child_project = Issue.find(5)
    issue_in_grandchild_project = Issue.generate!(:project_id => 6, :tracker_id => 1)
    issue_in_other_child_project = Issue.find(6)
    issue_in_different_tree = Issue.find(4)

    with_settings :cross_project_subtasks => '' do
      assert_equal true, issue.valid_parent_project?(issue_in_same_project)
      assert_equal false, issue.valid_parent_project?(issue_in_child_project)
      assert_equal false, issue.valid_parent_project?(issue_in_grandchild_project)
      assert_equal false, issue.valid_parent_project?(issue_in_different_tree)
    end

    with_settings :cross_project_subtasks => 'system' do
      assert_equal true, issue.valid_parent_project?(issue_in_same_project)
      assert_equal true, issue.valid_parent_project?(issue_in_child_project)
      assert_equal true, issue.valid_parent_project?(issue_in_different_tree)
    end

    with_settings :cross_project_subtasks => 'tree' do
      assert_equal true, issue.valid_parent_project?(issue_in_same_project)
      assert_equal true, issue.valid_parent_project?(issue_in_child_project)
      assert_equal true, issue.valid_parent_project?(issue_in_grandchild_project)
      assert_equal false, issue.valid_parent_project?(issue_in_different_tree)

      assert_equal true, issue_in_child_project.valid_parent_project?(issue_in_same_project)
      assert_equal true, issue_in_child_project.valid_parent_project?(issue_in_other_child_project)
    end

    with_settings :cross_project_subtasks => 'descendants' do
      assert_equal true, issue.valid_parent_project?(issue_in_same_project)
      assert_equal false, issue.valid_parent_project?(issue_in_child_project)
      assert_equal false, issue.valid_parent_project?(issue_in_grandchild_project)
      assert_equal false, issue.valid_parent_project?(issue_in_different_tree)

      assert_equal true, issue_in_child_project.valid_parent_project?(issue)
      assert_equal false, issue_in_child_project.valid_parent_project?(issue_in_other_child_project)
    end
  end

  def test_recipients_should_include_previous_assignee
    user = User.find(3)
    user.members.update_all ["mail_notification = ?", false]
    user.update! :mail_notification => 'only_assigned'
    issue = Issue.find(2)

    issue.assigned_to = nil
    assert_include user.mail, issue.recipients
    issue.save!
    assert_include user.mail, issue.recipients

    issue.assigned_to = User.find(2)
    issue.save!
    assert !issue.recipients.include?(user.mail)
  end

  def test_recipients_should_not_include_users_that_cannot_view_the_issue
    issue = Issue.find(12)
    assert issue.recipients.include?(issue.author.mail)
    # copy the issue to a private project
    copy  = issue.copy(:project_id => 5, :tracker_id => 2)
    # author is not a member of project anymore
    assert !copy.recipients.include?(copy.author.mail)
  end

  def test_recipients_should_include_the_assigned_group_members
    group_member = User.generate!
    group = Group.generate!
    group.users << group_member

    issue = Issue.find(12)
    issue.assigned_to = group
    assert issue.recipients.include?(group_member.mail)
  end

  def test_watcher_recipients_should_not_include_users_that_cannot_view_the_issue
    user = User.find(3)
    issue = Issue.find(9)
    Watcher.create!(:user => user, :watchable => issue)
    assert issue.watched_by?(user)
    assert !issue.watcher_recipients.include?(user.mail)
  end

  def test_issue_destroy
    Issue.find(1).destroy
    assert_nil Issue.find_by_id(1)
    assert_nil TimeEntry.find_by_issue_id(1)
  end

  def test_destroy_should_delete_time_entries_custom_values
    issue = Issue.generate!
    time_entry = TimeEntry.generate!(:issue => issue, :custom_field_values => {10 => '1'})

    assert_difference 'CustomValue.where(:customized_type => "TimeEntry").count', -1 do
      assert issue.destroy
    end
  end

  def test_destroying_a_deleted_issue_should_not_raise_an_error
    issue = Issue.find(1)
    Issue.find(1).destroy

    assert_nothing_raised do
      assert_no_difference 'Issue.count' do
        issue.destroy
      end
      assert issue.destroyed?
    end
  end

  def test_destroying_a_stale_issue_should_not_raise_an_error
    issue = Issue.find(1)
    Issue.find(1).update! :subject => "Updated"

    assert_nothing_raised do
      assert_difference 'Issue.count', -1 do
        issue.destroy
      end
      assert issue.destroyed?
    end
  end

  def test_blocked
    blocked_issue = Issue.find(9)
    blocking_issue = Issue.find(10)

    assert blocked_issue.blocked?
    assert !blocking_issue.blocked?
  end

  def test_blocked_issues_dont_allow_closed_statuses
    blocked_issue = Issue.find(9)

    allowed_statuses = blocked_issue.new_statuses_allowed_to(users(:users_002))
    assert !allowed_statuses.empty?
    closed_statuses = allowed_statuses.select {|st| st.is_closed?}
    assert closed_statuses.empty?
  end

  def test_unblocked_issues_allow_closed_statuses
    blocking_issue = Issue.find(10)

    allowed_statuses = blocking_issue.new_statuses_allowed_to(users(:users_002))
    assert !allowed_statuses.empty?
    closed_statuses = allowed_statuses.select {|st| st.is_closed?}
    assert !closed_statuses.empty?
  end

  def test_parent_issues_with_open_subtask_dont_allow_closed_statuses
    parent = Issue.generate!
    child = Issue.generate!(:parent_issue_id => parent.id)

    allowed_statuses = parent.reload.new_statuses_allowed_to(users(:users_002))

    assert !parent.closable?
    assert_equal l(:notice_issue_not_closable_by_open_tasks), parent.transition_warning

    assert allowed_statuses.any?
    assert_equal [], allowed_statuses.select(&:is_closed?)
  end

  def test_parent_issues_with_closed_subtask_allow_closed_statuses
    parent = Issue.generate!
    child = Issue.generate!(:parent_issue_id => parent.id, :status_id => 5)

    allowed_statuses = parent.reload.new_statuses_allowed_to(users(:users_002))

    assert parent.closable?
    assert_nil parent.transition_warning
    assert allowed_statuses.any?
    assert allowed_statuses.select(&:is_closed?).any?
  end

  def test_reschedule_an_issue_without_dates
    with_settings :non_working_week_days => [] do
      issue = Issue.new(:start_date => nil, :due_date => nil)
      issue.reschedule_on '2012-10-09'.to_date
      assert_equal '2012-10-09'.to_date, issue.start_date
      assert_equal '2012-10-09'.to_date, issue.due_date
    end

    with_settings :non_working_week_days => %w(6 7) do
      issue = Issue.new(:start_date => nil, :due_date => nil)
      issue.reschedule_on '2012-10-09'.to_date
      assert_equal '2012-10-09'.to_date, issue.start_date
      assert_equal '2012-10-09'.to_date, issue.due_date

      issue = Issue.new(:start_date => nil, :due_date => nil)
      issue.reschedule_on '2012-10-13'.to_date
      assert_equal '2012-10-15'.to_date, issue.start_date
      assert_equal '2012-10-15'.to_date, issue.due_date
    end
  end

  def test_reschedule_an_issue_with_start_date
    with_settings :non_working_week_days => [] do
      issue = Issue.new(:start_date => '2012-10-09', :due_date => nil)
      issue.reschedule_on '2012-10-13'.to_date
      assert_equal '2012-10-13'.to_date, issue.start_date
      assert_equal '2012-10-13'.to_date, issue.due_date
    end

    with_settings :non_working_week_days => %w(6 7) do
      issue = Issue.new(:start_date => '2012-10-09', :due_date => nil)
      issue.reschedule_on '2012-10-11'.to_date
      assert_equal '2012-10-11'.to_date, issue.start_date
      assert_equal '2012-10-11'.to_date, issue.due_date

      issue = Issue.new(:start_date => '2012-10-09', :due_date => nil)
      issue.reschedule_on '2012-10-13'.to_date
      assert_equal '2012-10-15'.to_date, issue.start_date
      assert_equal '2012-10-15'.to_date, issue.due_date
    end
  end

  def test_reschedule_an_issue_with_start_and_due_dates
    with_settings :non_working_week_days => [] do
      issue = Issue.new(:start_date => '2012-10-09', :due_date => '2012-10-15')
      issue.reschedule_on '2012-10-13'.to_date
      assert_equal '2012-10-13'.to_date, issue.start_date
      assert_equal '2012-10-19'.to_date, issue.due_date
    end

    with_settings :non_working_week_days => %w(6 7) do
      issue = Issue.new(:start_date => '2012-10-09', :due_date => '2012-10-19') # 8 working days
      issue.reschedule_on '2012-10-11'.to_date
      assert_equal '2012-10-11'.to_date, issue.start_date
      assert_equal '2012-10-23'.to_date, issue.due_date

      issue = Issue.new(:start_date => '2012-10-09', :due_date => '2012-10-19')
      issue.reschedule_on '2012-10-13'.to_date
      assert_equal '2012-10-15'.to_date, issue.start_date
      assert_equal '2012-10-25'.to_date, issue.due_date
    end
  end

  def test_rescheduling_an_issue_to_a_later_due_date_should_reschedule_following_issue
    with_settings :non_working_week_days => [] do
      issue1 = Issue.generate!(:start_date => '2012-10-15', :due_date => '2012-10-17')
      issue2 = Issue.generate!(:start_date => '2012-10-15', :due_date => '2012-10-17')
      IssueRelation.create!(:issue_from => issue1, :issue_to => issue2,
                            :relation_type => IssueRelation::TYPE_PRECEDES)
      assert_equal Date.parse('2012-10-18'), issue2.reload.start_date

      issue1.reload
      issue1.due_date = '2012-10-23'
      issue1.save!
      issue2.reload
      assert_equal Date.parse('2012-10-24'), issue2.start_date
      assert_equal Date.parse('2012-10-26'), issue2.due_date
    end

    # The delay should honor non-working week days
    with_settings :non_working_week_days => %w(6 7) do
      issue1 = Issue.generate!(:start_date => '2014-03-10', :due_date => '2014-03-12')
      issue2 = Issue.generate!(:start_date => '2014-03-10', :due_date => '2014-03-12')
      IssueRelation.create!(:issue_from => issue1, :issue_to => issue2,
                            :relation_type => IssueRelation::TYPE_PRECEDES,
                            :delay => 8)
      assert_equal Date.parse('2014-03-25'), issue2.reload.start_date
    end
  end

  def test_rescheduling_an_issue_to_an_earlier_due_date_should_reschedule_following_issue
    issue1 = Issue.generate!(:start_date => '2012-10-15', :due_date => '2012-10-17')
    issue2 = Issue.generate!(:start_date => '2012-10-15', :due_date => '2012-10-17')
    IssueRelation.create!(:issue_from => issue1, :issue_to => issue2,
                          :relation_type => IssueRelation::TYPE_PRECEDES)
    assert_equal Date.parse('2012-10-18'), issue2.reload.start_date

    issue1.reload
    issue1.start_date = '2012-09-17'
    issue1.due_date = '2012-09-18'
    issue1.save!
    issue2.reload
    assert_equal Date.parse('2012-09-19'), issue2.start_date
    assert_equal Date.parse('2012-09-21'), issue2.due_date
  end

  def test_rescheduling_an_issue_to_a_different_due_date_should_add_journal_to_following_issue
    with_settings :non_working_week_days => [] do
      issue1 = Issue.generate!(:start_date => '2012-10-15', :due_date => '2012-10-17')
      issue2 = Issue.generate!(:start_date => '2012-10-18', :due_date => '2012-10-20')
      IssueRelation.create!(:issue_from => issue1, :issue_to => issue2,
                            :relation_type => IssueRelation::TYPE_PRECEDES)

      assert_difference 'issue2.journals.count' do
        issue1.reload
        issue1.init_journal(User.find(3))
        issue1.due_date = '2012-10-23'
        issue1.save!
      end
      journal = issue2.journals.order(:id).last

      start_date_detail = journal.details.find_by(:prop_key => 'start_date')
      assert_equal '2012-10-18', start_date_detail.old_value
      assert_equal '2012-10-24', start_date_detail.value

      due_date_detail = journal.details.find_by(:prop_key => 'due_date')
      assert_equal '2012-10-20', due_date_detail.old_value
      assert_equal '2012-10-26', due_date_detail.value
    end
  end

  def test_rescheduling_reschedule_following_issue_earlier_should_consider_other_preceding_issues
    issue1 = Issue.generate!(:start_date => '2012-10-15', :due_date => '2012-10-17')
    issue2 = Issue.generate!(:start_date => '2012-10-15', :due_date => '2012-10-17')
    issue3 = Issue.generate!(:start_date => '2012-10-01', :due_date => '2012-10-02')
    IssueRelation.create!(:issue_from => issue1, :issue_to => issue2,
                          :relation_type => IssueRelation::TYPE_PRECEDES)
    IssueRelation.create!(:issue_from => issue3, :issue_to => issue2,
                          :relation_type => IssueRelation::TYPE_PRECEDES)
    assert_equal Date.parse('2012-10-18'), issue2.reload.start_date

    issue1.reload
    issue1.start_date = '2012-09-17'
    issue1.due_date = '2012-09-18'
    issue1.save!
    issue2.reload
    # Issue 2 must start after Issue 3
    assert_equal Date.parse('2012-10-03'), issue2.start_date
    assert_equal Date.parse('2012-10-05'), issue2.due_date
  end

  def test_rescheduling_a_stale_issue_should_not_raise_an_error
    with_settings :non_working_week_days => [] do
      stale = Issue.find(1)
      issue = Issue.find(1)
      issue.subject = "Updated"
      issue.save!
      date = 10.days.from_now.to_date
      assert_nothing_raised do
        stale.reschedule_on!(date)
      end
      assert_equal date, stale.reload.start_date
    end
  end

  def test_child_issue_should_consider_parent_soonest_start_on_create
    set_language_if_valid 'en'
    issue1 = Issue.generate!(:start_date => '2012-10-15', :due_date => '2012-10-17')
    issue2 = Issue.generate!(:start_date => '2012-10-18', :due_date => '2012-10-20')
    IssueRelation.create!(:issue_from => issue1, :issue_to => issue2,
                          :relation_type => IssueRelation::TYPE_PRECEDES)
    issue1.reload
    issue2.reload
    assert_equal Date.parse('2012-10-18'), issue2.start_date

    with_settings :date_format => '%m/%d/%Y' do
      child = Issue.new(:parent_issue_id => issue2.id, :start_date => '2012-10-16',
        :project_id => 1, :tracker_id => 1, :status_id => 1, :subject => 'Child', :author_id => 1)
      assert !child.valid?
      assert_include 'Start date cannot be earlier than 10/18/2012 because of preceding issues', child.errors.full_messages
      assert_equal Date.parse('2012-10-18'), child.soonest_start
      child.start_date = '2012-10-18'
      assert child.save
    end
  end

  def test_setting_parent_to_a_an_issue_that_precedes_should_not_validate
    # tests that 3 cannot have 1 as parent:
    #
    # 1 -> 2 -> 3
    #
    set_language_if_valid 'en'
    issue1 = Issue.generate!
    issue2 = Issue.generate!
    issue3 = Issue.generate!
    IssueRelation.create!(:issue_from => issue1, :issue_to => issue2, :relation_type => IssueRelation::TYPE_PRECEDES)
    IssueRelation.create!(:issue_from => issue2, :issue_to => issue3, :relation_type => IssueRelation::TYPE_PRECEDES)
    issue3.reload
    issue3.parent_issue_id = issue1.id
    assert !issue3.valid?
    assert_include 'Parent task is invalid', issue3.errors.full_messages
  end

  def test_setting_parent_to_a_an_issue_that_follows_should_not_validate
    # tests that 1 cannot have 3 as parent:
    #
    # 1 -> 2 -> 3
    #
    set_language_if_valid 'en'
    issue1 = Issue.generate!
    issue2 = Issue.generate!
    issue3 = Issue.generate!
    IssueRelation.create!(:issue_from => issue1, :issue_to => issue2, :relation_type => IssueRelation::TYPE_PRECEDES)
    IssueRelation.create!(:issue_from => issue2, :issue_to => issue3, :relation_type => IssueRelation::TYPE_PRECEDES)
    issue1.reload
    issue1.parent_issue_id = issue3.id
    assert !issue1.valid?
    assert_include 'Parent task is invalid', issue1.errors.full_messages
  end

  def test_setting_parent_to_a_an_issue_that_precedes_through_hierarchy_should_not_validate
    # tests that 4 cannot have 1 as parent:
    # changing the due date of 4 would update the end date of 1 which would reschedule 2
    # which would change the end date of 3 which would reschedule 4 and so on...
    #
    #      3 -> 4
    #      ^
    # 1 -> 2
    #
    set_language_if_valid 'en'
    issue1 = Issue.generate!
    issue2 = Issue.generate!
    IssueRelation.create!(:issue_from => issue1, :issue_to => issue2, :relation_type => IssueRelation::TYPE_PRECEDES)
    issue3 = Issue.generate!
    issue2.reload
    issue2.parent_issue_id = issue3.id
    issue2.save!
    issue4 = Issue.generate!
    IssueRelation.create!(:issue_from => issue3, :issue_to => issue4, :relation_type => IssueRelation::TYPE_PRECEDES)
    issue4.reload
    issue4.parent_issue_id = issue1.id
    assert !issue4.valid?
    assert_include 'Parent task is invalid', issue4.errors.full_messages
  end

  def test_issue_and_following_issue_should_be_able_to_be_moved_to_the_same_parent
    set_language_if_valid 'en'
    issue1 = Issue.generate!
    issue2 = Issue.generate!
    relation = IssueRelation.create!(:issue_from => issue2, :issue_to => issue1, :relation_type => IssueRelation::TYPE_FOLLOWS)
    parent = Issue.generate!
    issue1.reload.parent_issue_id = parent.id
    assert_save issue1
    parent.reload
    issue2.reload.parent_issue_id = parent.id
    assert_save issue2
    assert IssueRelation.exists?(relation.id)
  end

  def test_issue_and_preceding_issue_should_be_able_to_be_moved_to_the_same_parent
    set_language_if_valid 'en'
    issue1 = Issue.generate!
    issue2 = Issue.generate!
    relation = IssueRelation.create!(:issue_from => issue2, :issue_to => issue1, :relation_type => IssueRelation::TYPE_PRECEDES)
    parent = Issue.generate!
    issue1.reload.parent_issue_id = parent.id
    assert_save issue1
    parent.reload
    issue2.reload.parent_issue_id = parent.id
    assert_save issue2
    assert IssueRelation.exists?(relation.id)
  end

  def test_issue_and_blocked_issue_should_be_able_to_be_moved_to_the_same_parent
    set_language_if_valid 'en'
    issue1 = Issue.generate!
    issue2 = Issue.generate!
    relation = IssueRelation.create!(:issue_from => issue2, :issue_to => issue1, :relation_type => IssueRelation::TYPE_BLOCKED)
    parent = Issue.generate!
    issue1.reload.parent_issue_id = parent.id
    assert_save issue1
    parent.reload
    issue2.reload.parent_issue_id = parent.id
    assert_save issue2
    assert IssueRelation.exists?(relation.id)
  end

  def test_issue_and_blocking_issue_should_be_able_to_be_moved_to_the_same_parent
    set_language_if_valid 'en'
    issue1 = Issue.generate!
    issue2 = Issue.generate!
    relation = IssueRelation.create!(:issue_from => issue2, :issue_to => issue1, :relation_type => IssueRelation::TYPE_BLOCKS)
    parent = Issue.generate!
    issue1.reload.parent_issue_id = parent.id
    assert_save issue1
    parent.reload
    issue2.reload.parent_issue_id = parent.id
    assert_save issue2
    assert IssueRelation.exists?(relation.id)
  end

  def test_issue_copy_should_be_able_to_be_moved_to_the_same_parent_as_copied_issue
    issue = Issue.generate!
    parent = Issue.generate!
    issue.parent_issue_id = parent.id
    issue.save!
    issue.reload

    copy = Issue.new.copy_from(issue, :link => true)
    relation = new_record(IssueRelation) do
      copy.save!
    end
    copy.reload

    copy.parent_issue_id = parent.id
    assert_save copy
    assert IssueRelation.exists?(relation.id)
  end

  def test_overdue
    User.current = nil
    today = User.current.today
    assert  Issue.new(:due_date => (today - 1.day).to_date).overdue?
    assert !Issue.new(:due_date => today).overdue?
    assert !Issue.new(:due_date => (today + 1.day).to_date).overdue?
    assert !Issue.new(:due_date => nil).overdue?
    assert !Issue.
              new(
                :due_date => (today - 1.day).to_date,
                :status => IssueStatus.where(:is_closed => true).first
              ).overdue?
  end

  test "#behind_schedule? should be false if the issue has no start_date" do
    assert !Issue.new(:start_date => nil,
                      :due_date => 1.day.from_now.to_date,
                      :done_ratio => 0).behind_schedule?
  end

  test "#behind_schedule? should be false if the issue has no end_date" do
    assert !Issue.new(:start_date => 1.day.from_now.to_date,
                      :due_date => nil,
                      :done_ratio => 0).behind_schedule?
  end

  test "#behind_schedule? should be false if the issue has more done than it's calendar time" do
    assert !Issue.new(:start_date => 50.days.ago.to_date,
                      :due_date => 50.days.from_now.to_date,
                      :done_ratio => 90).behind_schedule?
  end

  test "#behind_schedule? should be true if the issue hasn't been started at all" do
    assert Issue.new(:start_date => 1.day.ago.to_date,
                     :due_date => 1.day.from_now.to_date,
                     :done_ratio => 0).behind_schedule?
  end

  test "#behind_schedule? should be true if the issue has used more calendar time than it's done ratio" do
    assert Issue.new(:start_date => 100.days.ago.to_date,
                     :due_date => Date.today,
                     :done_ratio => 90).behind_schedule?
  end

  test "#assignable_users should be Users" do
    assert_kind_of User, Issue.find(1).assignable_users.first
  end

  test "#assignable_users should include the issue author" do
    non_project_member = User.generate!
    issue = Issue.generate!(:author => non_project_member)

    assert issue.assignable_users.include?(non_project_member)
  end

  def test_assignable_users_should_not_include_anonymous_user
    issue = Issue.generate!(:author => User.anonymous)

    assert !issue.assignable_users.include?(User.anonymous)
  end

  def test_assignable_users_should_not_include_locked_user
    user = User.generate!
    issue = Issue.generate!(:author => user)
    user.lock!

    assert !issue.assignable_users.include?(user)
  end

  def test_assignable_users_should_include_the_current_assignee
    user = User.generate!
    Member.create!(:project_id => 1, :principal => user, :role_ids => [1])
    issue = Issue.generate!(:assigned_to => user)
    user.lock!

    assert Issue.find(issue.id).assignable_users.include?(user)
  end

  test "#assignable_users should not show the issue author twice" do
    assignable_user_ids = Issue.find(1).assignable_users.collect(&:id)
    assert_equal 2, assignable_user_ids.length

    assignable_user_ids.each do |user_id|
      assert_equal 1, assignable_user_ids.count {|i| i == user_id},
                   "User #{user_id} appears more or less than once"
    end
  end

  test "#assignable_users with issue_group_assignment should include groups" do
    issue = Issue.new(:project => Project.find(2))

    with_settings :issue_group_assignment => '1' do
      assert_equal %w(Group User), issue.assignable_users.map {|a| a.class.name}.uniq.sort
      assert issue.assignable_users.include?(Group.find(11))
    end
  end

  test "#assignable_users without issue_group_assignment should not include groups" do
    issue = Issue.new(:project => Project.find(2))

    with_settings :issue_group_assignment => '0' do
      assert_equal %w(User), issue.assignable_users.map {|a| a.class.name}.uniq.sort
      assert !issue.assignable_users.include?(Group.find(11))
    end
  end

  def test_assignable_users_should_not_include_builtin_groups
    Member.create!(:project_id => 1, :principal => Group.non_member, :role_ids => [1])
    Member.create!(:project_id => 1, :principal => Group.anonymous, :role_ids => [1])
    issue = Issue.new(:project => Project.find(1))

    with_settings :issue_group_assignment => '1' do
      assert_nil issue.assignable_users.detect {|u| u.is_a?(GroupBuiltin)}
    end
  end

  def test_assignable_users_should_not_include_users_that_cannot_view_the_tracker
    user = User.find(3)
    role = Role.find(2)
    role.set_permission_trackers :view_issues, [1, 3]
    role.save!

    issue1 = Issue.new(:project_id => 1, :tracker_id => 1)
    issue2 = Issue.new(:project_id => 1, :tracker_id => 2)

    assert_include user, issue1.assignable_users
    assert_not_include user, issue2.assignable_users
  end

  def test_create_should_send_email_notification
    ActionMailer::Base.deliveries.clear
    issue = Issue.new(:project_id => 1, :tracker_id => 1,
                      :author_id => 3, :status_id => 1,
                      :priority => IssuePriority.all.first,
                      :subject => 'test_create', :estimated_hours => '1:30')
    with_settings :notified_events => %w(issue_added) do
      assert issue.save
      assert_equal 2, ActionMailer::Base.deliveries.size
    end
  end

  def test_create_should_send_one_email_notification_with_both_settings
    ActionMailer::Base.deliveries.clear
    issue = Issue.new(:project_id => 1, :tracker_id => 1,
                      :author_id => 3, :status_id => 1,
                      :priority => IssuePriority.all.first,
                      :subject => 'test_create', :estimated_hours => '1:30')
    with_settings :notified_events => %w(issue_added issue_updated) do
      assert issue.save
      assert_equal 2, ActionMailer::Base.deliveries.size
    end
  end

  def test_create_should_not_send_email_notification_with_no_setting
    ActionMailer::Base.deliveries.clear
    issue = Issue.new(:project_id => 1, :tracker_id => 1,
                      :author_id => 3, :status_id => 1,
                      :priority => IssuePriority.all.first,
                      :subject => 'test_create', :estimated_hours => '1:30')
    with_settings :notified_events => [] do
      assert issue.save
      assert_equal 0, ActionMailer::Base.deliveries.size
    end
  end

  def test_update_should_notify_previous_assignee
    ActionMailer::Base.deliveries.clear
    user = User.find(3)
    user.members.update_all ["mail_notification = ?", false]
    user.update! :mail_notification => 'only_assigned'

    with_settings :notified_events => %w(issue_updated) do
      issue = Issue.find(2)
      issue.init_journal User.find(1)
      issue.assigned_to = nil
      issue.save!

      assert_include [user.mail], ActionMailer::Base.deliveries.map(&:to)
    end
  end

  def test_stale_issue_should_not_send_email_notification
    ActionMailer::Base.deliveries.clear
    issue = Issue.find(1)
    stale = Issue.find(1)

    issue.init_journal(User.find(1))
    issue.subject = 'Subjet update'
    with_settings :notified_events => %w(issue_updated) do
      assert issue.save
      assert_equal 2, ActionMailer::Base.deliveries.size
      ActionMailer::Base.deliveries.clear

      stale.init_journal(User.find(1))
      stale.subject = 'Another subjet update'
      assert_raise ActiveRecord::StaleObjectError do
        stale.save
      end
      assert ActionMailer::Base.deliveries.empty?
    end
  end

  def test_journalized_description
    IssueCustomField.delete_all

    i = Issue.first
    old_description = i.description
    new_description = "This is the new description"

    i.init_journal(User.find(2))
    i.description = new_description
    assert_difference 'Journal.count', 1 do
      assert_difference 'JournalDetail.count', 1 do
        i.save!
      end
    end

    detail = JournalDetail.order('id DESC').first
    assert_equal i, detail.journal.journalized
    assert_equal 'attr', detail.property
    assert_equal 'description', detail.prop_key
    assert_equal old_description, detail.old_value
    assert_equal new_description, detail.value
  end

  def test_blank_descriptions_should_not_be_journalized
    IssueCustomField.delete_all
    Issue.where(:id => 1).update_all("description = NULL")

    i = Issue.find(1)
    i.init_journal(User.find(2))
    i.subject = "blank description"
    i.description = "\r\n"

    assert_difference 'Journal.count', 1 do
      assert_difference 'JournalDetail.count', 1 do
        i.save!
      end
    end
  end

  def test_journalized_multi_custom_field
    field = IssueCustomField.create!(:name => 'filter', :field_format => 'list',
                                     :is_filter => true, :is_for_all => true,
                                     :tracker_ids => [1],
                                     :possible_values => ['value1', 'value2', 'value3'],
                                     :multiple => true)

    issue = Issue.generate!(:project_id => 1, :tracker_id => 1,
                          :subject => 'Test', :author_id => 1)

    assert_difference 'Journal.count' do
      assert_difference 'JournalDetail.count' do
        issue.init_journal(User.first)
        issue.custom_field_values = {field.id => ['value1']}
        issue.save!
      end
      assert_difference 'JournalDetail.count' do
        issue.init_journal(User.first)
        issue.custom_field_values = {field.id => ['value1', 'value2']}
        issue.save!
      end
      assert_difference 'JournalDetail.count', 2 do
        issue.init_journal(User.first)
        issue.custom_field_values = {field.id => ['value3', 'value2']}
        issue.save!
      end
      assert_difference 'JournalDetail.count', 2 do
        issue.init_journal(User.first)
        issue.custom_field_values = {field.id => nil}
        issue.save!
      end
    end
  end

  def test_custom_value_cleared_on_tracker_change_should_be_journalized
    a = IssueCustomField.generate!(:tracker_ids => [1])
    issue = Issue.generate!(:project_id => 1, :tracker_id => 1, :custom_field_values => {a.id.to_s => "foo"})
    assert_equal "foo", issue.custom_field_value(a)

    journal = new_record(Journal) do
      issue.init_journal(User.first)
      issue.tracker_id = 2
      issue.save!
    end
    details = journal.details.select {|d| d.property == 'cf' && d.prop_key == a.id.to_s}
    assert_equal 1, details.size
    assert_equal 'foo', details.first.old_value
    assert_nil details.first.value
  end

  def test_description_eol_should_be_normalized
    i = Issue.new(:description => "CR \r LF \n CRLF \r\n")
    assert_equal "CR \r\n LF \r\n CRLF \r\n", i.description
  end

  def test_saving_twice_should_not_duplicate_journal_details
    i = Issue.first
    i.init_journal(User.find(2), 'Some notes')
    # initial changes
    i.subject = 'New subject'
    i.done_ratio = i.done_ratio + 10
    assert_difference 'Journal.count' do
      assert i.save
    end
    # 1 more change
    i.priority = IssuePriority.where("id <> ?", i.priority_id).first
    assert_no_difference 'Journal.count' do
      assert_difference 'JournalDetail.count', 1 do
        i.save
      end
    end
    # no more change
    assert_no_difference 'Journal.count' do
      assert_no_difference 'JournalDetail.count' do
        i.save
      end
    end
  end

  test "#done_ratio should use the issue_status according to Setting.issue_done_ratio" do
    @issue = Issue.find(1)
    @issue_status = IssueStatus.find(1)
    @issue_status.update!(:default_done_ratio => 50)
    @issue2 = Issue.find(2)
    @issue_status2 = IssueStatus.find(2)
    @issue_status2.update!(:default_done_ratio => 0)

    with_settings :issue_done_ratio => 'issue_field' do
      assert_equal 0, @issue.done_ratio
      assert_equal 30, @issue2.done_ratio
    end

    with_settings :issue_done_ratio => 'issue_status' do
      assert_equal 50, @issue.done_ratio
      assert_equal 0, @issue2.done_ratio
    end
  end

  test "#update_done_ratio_from_issue_status should update done_ratio according to Setting.issue_done_ratio" do
    @issue = Issue.find(1)
    @issue_status = IssueStatus.find(1)
    @issue_status.update!(:default_done_ratio => 50)
    @issue2 = Issue.find(2)
    @issue_status2 = IssueStatus.find(2)
    @issue_status2.update!(:default_done_ratio => 0)

    with_settings :issue_done_ratio => 'issue_field' do
      @issue.update_done_ratio_from_issue_status
      @issue2.update_done_ratio_from_issue_status

      assert_equal 0, @issue.read_attribute(:done_ratio)
      assert_equal 30, @issue2.read_attribute(:done_ratio)
    end

    with_settings :issue_done_ratio => 'issue_status' do
      @issue.update_done_ratio_from_issue_status
      @issue2.update_done_ratio_from_issue_status

      assert_equal 50, @issue.read_attribute(:done_ratio)
      assert_equal 0, @issue2.read_attribute(:done_ratio)
    end
  end

  test "#by_tracker" do
    User.current = User.find(2)
    groups = Issue.by_tracker(Project.find(1))
    groups_containing_subprojects = Issue.by_tracker(Project.find(1), true)
    assert_equal 7, groups.inject(0) {|sum, group| sum + group['total'].to_i}
    assert_equal 13, groups_containing_subprojects.inject(0) {|sum, group| sum + group['total'].to_i}
  end

  test "#by_version" do
    User.current = User.find(2)
    project = Project.find(1)
    Issue.generate!(:project_id => project.descendants.visible.first, :fixed_version_id => project.shared_versions.find_by(:sharing => 'tree').id)

    groups = Issue.by_version(project)
    groups_containing_subprojects = Issue.by_version(project, true)
    assert_equal 7, groups.inject(0) {|sum, group| sum + group['total'].to_i}
    assert_equal 14, groups_containing_subprojects.inject(0) {|sum, group| sum + group['total'].to_i}
  end

  test "#by_priority" do
    User.current = User.find(2)
    project = Project.find(1)
    groups = Issue.by_priority(project)
    groups_containing_subprojects = Issue.by_priority(project, true)
    assert_equal 7, groups.inject(0) {|sum, group| sum + group['total'].to_i}
    assert_equal 13, groups_containing_subprojects.inject(0) {|sum, group| sum + group['total'].to_i}
  end

  test "#by_category" do
    User.current = User.find(2)
    project = Project.find(1)
    issue_category = IssueCategory.create(:project => project.descendants.visible.first, :name => 'test category')
    Issue.generate!(:project_id => project.descendants.visible.first, :category_id => issue_category.id)

    groups = Issue.by_category(project)
    groups_containing_subprojects = Issue.by_category(project, true)
    assert_equal 7, groups.inject(0) {|sum, group| sum + group['total'].to_i}
    assert_equal 14, groups_containing_subprojects.inject(0) {|sum, group| sum + group['total'].to_i}
  end

  test "#by_assigned_to" do
    User.current = User.find(2)
    project = Project.find(1)
    Issue.generate!(:project_id => project.descendants.visible.first, :assigned_to => User.current)

    groups = Issue.by_assigned_to(project)
    groups_containing_subprojects = Issue.by_assigned_to(project, true)
    assert_equal 7, groups.inject(0) {|sum, group| sum + group['total'].to_i}
    assert_equal 14, groups_containing_subprojects.inject(0) {|sum, group| sum + group['total'].to_i}
  end

  test "#by_author" do
    User.current = User.find(2)
    project = Project.find(1)
    groups = Issue.by_author(project)
    groups_containing_subprojects = Issue.by_author(project, true)
    assert_equal 7, groups.inject(0) {|sum, group| sum + group['total'].to_i}
    assert_equal 13, groups_containing_subprojects.inject(0) {|sum, group| sum + group['total'].to_i}
  end

  test "#by_subproject" do
    User.current = User.anonymous
    groups = Issue.by_subproject(Project.find(1))
    # Private descendant not visible
    assert_equal 1, groups.count
    assert_equal 2, groups.inject(0) {|sum, group| sum + group['total'].to_i}
  end

  def test_recently_updated_scope
    # should return the last updated issue
    assert_equal Issue.reorder("updated_on DESC").first, Issue.recently_updated.limit(1).first
  end

  def test_on_active_projects_scope
    assert Project.find(2).archive

    before = Issue.on_active_project.length
    # test inclusion to results
    issue = Issue.generate!(:tracker => Project.find(2).trackers.first)
    assert_equal before + 1, Issue.on_active_project.length

    # Move to an archived project
    issue.project = Project.find(2)
    assert issue.save
    assert_equal before, Issue.on_active_project.length
  end

  test "Issue#recipients should include project recipients" do
    issue = Issue.generate!
    assert issue.project.recipients.present?
    issue.project.recipients.each do |project_recipient|
      assert issue.recipients.include?(project_recipient)
    end
  end

  test "Issue#recipients should include the author if the author is active" do
    issue = Issue.generate!(:author => User.generate!)
    assert issue.author, "No author set for Issue"
    assert issue.recipients.include?(issue.author.mail)
  end

  test "Issue#recipients should include the assigned to user if the assigned to user is active" do
    user = User.generate!
    Member.create!(:project_id => 1, :principal => user, :role_ids => [1])
    issue = Issue.generate!(:assigned_to => user)
    assert issue.assigned_to, "No assigned_to set for Issue"
    assert issue.recipients.include?(issue.assigned_to.mail)
  end

  test "Issue#recipients should not include users who opt out of all email" do
    issue = Issue.generate!(:author => User.generate!)
    issue.author.update!(:mail_notification => :none)
    assert !issue.recipients.include?(issue.author.mail)
  end

  test "Issue#recipients should not include the issue author if they are only notified of assigned issues" do
    issue = Issue.generate!(:author => User.generate!)
    issue.author.update!(:mail_notification => :only_assigned)
    assert !issue.recipients.include?(issue.author.mail)
  end

  test "Issue#recipients should not include the assigned user if they are only notified of owned issues" do
    user = User.generate!
    Member.create!(:project_id => 1, :principal => user, :role_ids => [1])
    issue = Issue.generate!(:assigned_to => user)
    issue.assigned_to.update!(:mail_notification => :only_owner)
    assert !issue.recipients.include?(issue.assigned_to.mail)
  end

  test "Issue#recipients should include users who want to be notified about high issues but only when issue has high priority" do
    user = User.generate!
    user.pref.update! notify_about_high_priority_issues: true
    Member.create!(:project_id => 1, :principal => user, :role_ids => [1])

    # creation with high prio
    issue = Issue.generate!(priority: IssuePriority.find(6))
    assert issue.recipients.include?(user.mail)

    # creation with default prio
    issue = Issue.generate!
    assert !issue.recipients.include?(user.mail)

    # update prio to high
    issue.update! priority: IssuePriority.find(6)
    assert issue.recipients.include?(user.mail)

    # update prio to low
    issue.update! priority: IssuePriority.find(4)
    assert !issue.recipients.include?(user.mail)
  end

  test "Authors who don't want to be self-notified should not receive emails even when issue has high priority" do
    user = User.generate!
    user.pref.update! notify_about_high_priority_issues: true
    user.pref.update! no_self_notified: true

    project = Project.find(1)
    project.memberships.destroy_all
    Member.create!(:project_id => 1, :principal => user, :role_ids => [1])

    ActionMailer::Base.deliveries.clear
    Issue.create(author: user,
                 priority: IssuePriority.find(6),
                 subject: 'test create',
                 project: project,
                 tracker: Tracker.first,
                 status: IssueStatus.first)
    assert ActionMailer::Base.deliveries.empty?
  end

  def test_last_journal_id_with_journals_should_return_the_journal_id
    assert_equal 2, Issue.find(1).last_journal_id
  end

  def test_last_journal_id_without_journals_should_return_nil
    assert_nil Issue.find(3).last_journal_id
  end

  def test_journals_after_should_return_journals_with_greater_id
    assert_equal [Journal.find(2)], Issue.find(1).journals_after('1')
    assert_equal [], Issue.find(1).journals_after('2')
  end

  def test_journals_after_with_blank_arg_should_return_all_journals
    assert_equal [Journal.find(1), Journal.find(2)], Issue.find(1).journals_after('')
  end

  def test_css_classes_should_include_tracker
    issue = Issue.new(:tracker => Tracker.find(2))
    classes = issue.css_classes.split(' ')
    assert_include 'tracker-2', classes
  end

  def test_css_classes_should_include_priority
    issue = Issue.new(:priority => IssuePriority.find(8))
    classes = issue.css_classes.split(' ')
    assert_include 'priority-8', classes
    assert_include 'priority-highest', classes
  end

  def test_css_classes_should_include_user_and_group_assignment
    project = Project.first
    user = User.generate!
    group = Group.generate!
    Member.create!(:principal => group, :project => project, :role_ids => [1, 2])
    group.users << user
    assert user.member_of?(project)
    issue1 = Issue.generate(:assigned_to_id => group.id)
    assert_include 'assigned-to-my-group', issue1.css_classes(user)
    assert_not_include 'assigned-to-me', issue1.css_classes(user)
    issue2 = Issue.generate(:assigned_to_id => user.id)
    assert_not_include 'assigned-to-my-group', issue2.css_classes(user)
    assert_include 'assigned-to-me', issue2.css_classes(user)
  end

  def test_css_classes_behind_schedule
    assert_include 'behind-schedule', Issue.find(1).css_classes.split(' ')
    assert_not_include 'behind-schedule', Issue.find(2).css_classes.split(' ')
  end

  def test_save_attachments_with_hash_should_save_attachments_in_keys_order
    set_tmp_attachments_directory
    issue = Issue.generate!
    issue.save_attachments(
      {
        'p0' => {'file' => mock_file_with_options(:original_filename => 'upload')},
        '3' => {'file' => mock_file_with_options(:original_filename => 'bar')},
        '1' => {'file' => mock_file_with_options(:original_filename => 'foo')}
      }
    )
    issue.attach_saved_attachments

    assert_equal 3, issue.reload.attachments.count
    assert_equal %w(upload foo bar), issue.attachments.map(&:filename)
  end

  def test_save_attachments_with_array_should_warn_about_missing_tokens
    set_tmp_attachments_directory
    issue = Issue.generate!
    issue.save_attachments([{'token' => 'missing'}])
    assert !issue.save
    assert issue.errors[:base].present?
    assert_equal 0, issue.reload.attachments.count
  end

  def test_closed_on_should_be_nil_when_creating_an_open_issue
    issue = Issue.generate!(:status_id => 1).reload
    assert !issue.closed?
    assert_nil issue.closed_on
  end

  def test_closed_on_should_be_set_when_creating_a_closed_issue
    issue = Issue.generate!(:status_id => 5).reload
    assert issue.closed?
    assert_not_nil issue.closed_on
    assert_equal issue.updated_on, issue.closed_on
    assert_equal issue.created_on, issue.closed_on
  end

  def test_closed_on_should_be_nil_when_updating_an_open_issue
    issue = Issue.find(1)
    issue.subject = 'Not closed yet'
    issue.save!
    issue.reload
    assert_nil issue.closed_on
  end

  def test_closed_on_should_be_set_when_closing_an_open_issue
    issue = Issue.find(1)
    issue.subject = 'Now closed'
    issue.status_id = 5
    issue.save!
    issue.reload
    assert_not_nil issue.closed_on
    assert_equal issue.updated_on, issue.closed_on
  end

  def test_closed_on_should_not_be_updated_when_updating_a_closed_issue
    issue = Issue.open(false).first
    was_closed_on = issue.closed_on
    assert_not_nil was_closed_on
    issue.subject = 'Updating a closed issue'
    issue.save!
    issue.reload
    assert_equal was_closed_on, issue.closed_on
  end

  def test_closed_on_should_be_preserved_when_reopening_a_closed_issue
    issue = Issue.open(false).first
    was_closed_on = issue.closed_on
    assert_not_nil was_closed_on
    issue.subject = 'Reopening a closed issue'
    issue.status_id = 1
    issue.save!
    issue.reload
    assert !issue.closed?
    assert_equal was_closed_on, issue.closed_on
  end

  def test_status_was_should_return_nil_for_new_issue
    issue = Issue.new
    assert_nil issue.status_was
  end

  def test_status_was_should_return_status_before_change
    issue = Issue.find(1)
    issue.status = IssueStatus.find(2)
    assert_equal IssueStatus.find(1), issue.status_was
  end

  def test_status_was_should_return_status_before_change_with_status_id
    issue = Issue.find(1)
    assert_equal IssueStatus.find(1), issue.status
    issue.status_id = 2
    assert_equal IssueStatus.find(1), issue.status_was
  end

  def test_status_was_should_be_reset_on_save
    issue = Issue.find(1)
    issue.status = IssueStatus.find(2)
    assert_equal IssueStatus.find(1), issue.status_was
    assert issue.save!
    assert_equal IssueStatus.find(2), issue.status_was
  end

  def test_closing_should_return_true_when_closing_an_issue
    issue = Issue.find(1)
    issue.status = IssueStatus.find(2)
    assert_equal false, issue.closing?
    issue.status = IssueStatus.find(5)
    assert_equal true, issue.closing?
  end

  def test_closing_should_return_true_when_closing_an_issue_with_status_id
    issue = Issue.find(1)
    issue.status_id = 2
    assert_equal false, issue.closing?
    issue.status_id = 5
    assert_equal true, issue.closing?
  end

  def test_closing_should_return_true_for_new_closed_issue
    issue = Issue.new
    assert_equal false, issue.closing?
    issue.status = IssueStatus.find(5)
    assert_equal true, issue.closing?
  end

  def test_closing_should_return_true_for_new_closed_issue_with_status_id
    issue = Issue.new
    assert_equal false, issue.closing?
    issue.status_id = 5
    assert_equal true, issue.closing?
  end

  def test_closing_should_be_reset_after_save
    issue = Issue.find(1)
    issue.status_id = 5
    assert_equal true, issue.closing?
    issue.save!
    assert_equal false, issue.closing?
  end

  def test_reopening_should_return_true_when_reopening_an_issue
    issue = Issue.find(8)
    issue.status = IssueStatus.find(6)
    assert_equal false, issue.reopening?
    issue.status = IssueStatus.find(2)
    assert_equal true, issue.reopening?
  end

  def test_reopening_should_return_true_when_reopening_an_issue_with_status_id
    issue = Issue.find(8)
    issue.status_id = 6
    assert_equal false, issue.reopening?
    issue.status_id = 2
    assert_equal true, issue.reopening?
  end

  def test_reopening_should_return_false_for_new_open_issue
    issue = Issue.new
    issue.status = IssueStatus.find(1)
    assert_equal false, issue.reopening?
  end

  def test_reopening_should_be_reset_after_save
    issue = Issue.find(8)
    issue.status_id = 2
    assert_equal true, issue.reopening?
    issue.save!
    assert_equal false, issue.reopening?
  end

  def test_default_status_without_tracker_should_be_nil
    issue = Issue.new
    assert_nil issue.tracker
    assert_nil issue.default_status
  end

  def test_default_status_should_be_tracker_default_status
    issue = Issue.new(:tracker_id => 1)
    assert_not_nil issue.status
    assert_equal issue.tracker.default_status, issue.default_status
  end

  def test_initializing_with_tracker_should_set_default_status
    issue = Issue.new(:tracker => Tracker.find(1))
    assert_not_nil issue.status
    assert_equal issue.default_status, issue.status
  end

  def test_initializing_with_tracker_id_should_set_default_status
    issue = Issue.new(:tracker_id => 1)
    assert_not_nil issue.status
    assert_equal issue.default_status, issue.status
  end

  def test_setting_tracker_should_set_default_status
    issue = Issue.new
    issue.tracker = Tracker.find(1)
    assert_not_nil issue.status
    assert_equal issue.default_status, issue.status
  end

  def test_changing_tracker_should_set_default_status_if_status_was_default
    WorkflowTransition.delete_all
    WorkflowTransition.create! :role_id => 1, :tracker_id => 2, :old_status_id => 2, :new_status_id => 1
    Tracker.find(2).update! :default_status_id => 2

    issue = Issue.new(:tracker_id => 1, :status_id => 1)
    assert_equal IssueStatus.find(1), issue.status
    issue.tracker = Tracker.find(2)
    assert_equal IssueStatus.find(2), issue.status
  end

  def test_changing_tracker_should_set_default_status_if_status_is_not_used_by_tracker
    WorkflowTransition.delete_all
    Tracker.find(2).update! :default_status_id => 2

    issue = Issue.new(:tracker_id => 1, :status_id => 3)
    assert_equal IssueStatus.find(3), issue.status
    issue.tracker = Tracker.find(2)
    assert_equal IssueStatus.find(2), issue.status
  end

  def test_changing_tracker_should_keep_status_if_status_was_not_default_and_is_used_by_tracker
    WorkflowTransition.delete_all
    WorkflowTransition.create! :role_id => 1, :tracker_id => 2, :old_status_id => 2, :new_status_id => 3
    Tracker.find(2).update! :default_status_id => 2

    issue = Issue.new(:tracker_id => 1, :status_id => 3)
    assert_equal IssueStatus.find(3), issue.status
    issue.tracker = Tracker.find(2)
    assert_equal IssueStatus.find(3), issue.status
  end

  def test_previous_assignee_with_a_group
    group = Group.find(10)
    Member.create!(:project_id => 1, :principal => group, :role_ids => [1])

    with_settings :issue_group_assignment => '1' do
      issue = Issue.generate!(:assigned_to => group)
      issue.reload.assigned_to = nil
      assert_equal group, issue.previous_assignee
    end
  end

  def test_issue_overdue_should_respect_user_timezone
    user_in_europe = users(:users_001)
    user_in_europe.pref.update! :time_zone => 'UTC'

    user_in_asia = users(:users_002)
    user_in_asia.pref.update! :time_zone => 'Hongkong'

    issue = Issue.generate! :due_date => Date.parse('2016-03-20')

    # server time is UTC
    time = Time.parse '2016-03-20 20:00 UTC'
    Time.stubs(:now).returns(time)
    Date.stubs(:today).returns(time.to_date)

    # for a user in the same time zone as the server the issue is not overdue
    # yet
    User.current = user_in_europe
    assert !issue.overdue?

    # at the same time, a user in East Asia looks at the issue - it's already
    # March 21st and the issue should be marked overdue
    User.current = user_in_asia
    assert issue.overdue?
  end

  def test_closable
    issue10 = Issue.find(10)
    assert issue10.closable?
    assert_nil issue10.transition_warning

    # Issue blocked by another issue
    issue9 = Issue.find(9)
    assert !issue9.closable?
    assert_equal l(:notice_issue_not_closable_by_blocking_issue), issue9.transition_warning
  end

  def test_reopenable
    parent = Issue.generate!(:status_id => 5)
    child = parent.generate_child!(:status_id => 5)

    assert !child.reopenable?
    assert_equal l(:notice_issue_not_reopenable_by_closed_parent_issue), child.transition_warning
  end

  def test_filter_projects_scope
    Issue.send(:public, :filter_projects_scope)
    # Project eCookbook
    issue = Issue.find(1)

    assert_equal Project, issue.filter_projects_scope
    assert_equal Project, issue.filter_projects_scope('system')

    # Project Onlinestore (id 2) is not part of the tree
    assert_equal [1, 3, 4, 5, 6], Issue.find(5).filter_projects_scope('tree').ids.sort

    # Project "Private child of eCookbook"
    issue2 = Issue.find(9)

    # Projects "eCookbook Subproject 1" (id 3) and "eCookbook Subproject 1" (id 4) are not part of hierarchy
    assert_equal [1, 5, 6], issue2.filter_projects_scope('hierarchy').ids.sort

    # Project "Child of private child" is descendant of "Private child of eCookbook"
    assert_equal [5, 6], issue2.filter_projects_scope('descendants').ids.sort

    assert_equal [5], issue2.filter_projects_scope('').ids.sort
  end

  def test_like_should_escape_query
    issue = Issue.generate!(:subject => "asdf")
    r = Issue.like('as_f')
    assert_not_include issue, r
    r = Issue.like('as%f')
    assert_not_include issue, r

    issue = Issue.generate!(:subject => "as%f")
    r = Issue.like('as%f')
    assert_include issue, r

    issue = Issue.generate!(:subject => "as_f")
    r = Issue.like('as_f')
    assert_include issue, r
  end

  def test_like_should_tokenize
    r = Issue.like('issue today')
    assert_include Issue.find(7), r
  end
end
