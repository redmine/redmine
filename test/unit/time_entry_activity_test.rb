# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class TimeEntryActivityTest < ActiveSupport::TestCase
  fixtures :enumerations, :time_entries, :custom_fields,
           :issues, :projects, :users,
           :members, :roles, :member_roles,
           :trackers, :issue_statuses,
           :projects_trackers,
           :issue_categories,
           :groups_users,
           :enabled_modules

  include Redmine::I18n

  def test_should_be_an_enumeration
    assert TimeEntryActivity.ancestors.include?(Enumeration)
  end

  def test_objects_count
    assert_equal 3, TimeEntryActivity.find_by_name("Design").objects_count
    assert_equal 2, TimeEntryActivity.find_by_name("Development").objects_count
  end

  def test_option_name
    assert_equal :enumeration_activities, TimeEntryActivity.new.option_name
  end

  def test_create_with_custom_field
    field = TimeEntryActivityCustomField.find_by_name('Billable')
    e = TimeEntryActivity.new(:name => 'Custom Data')
    e.custom_field_values = {field.id => "1"}
    assert e.save

    e.reload
    assert_equal "1", e.custom_value_for(field).value
  end

  def test_create_without_required_custom_field_should_fail
    set_language_if_valid 'en'
    field = TimeEntryActivityCustomField.find_by_name('Billable')
    field.update_attribute(:is_required, true)

    e = TimeEntryActivity.new(:name => 'Custom Data')
    assert !e.save
    assert_equal ["Billable cannot be blank"], e.errors.full_messages
  end

  def test_create_with_required_custom_field_should_succeed
    field = TimeEntryActivityCustomField.find_by_name('Billable')
    field.update_attribute(:is_required, true)

    e = TimeEntryActivity.new(:name => 'Custom Data')
    e.custom_field_values = {field.id => "1"}
    assert e.save
  end

  def test_update_with_required_custom_field_change
    set_language_if_valid 'en'
    field = TimeEntryActivityCustomField.find_by_name('Billable')
    field.update_attribute(:is_required, true)

    e = TimeEntryActivity.find(10)
    assert e.available_custom_fields.include?(field)
    # No change to custom field, record can be saved
    assert e.save
    # Blanking custom field, save should fail
    e.custom_field_values = {field.id => ""}
    assert !e.save
    assert_equal ["Billable cannot be blank"], e.errors.full_messages

    # Update custom field to valid value, save should succeed
    e.custom_field_values = {field.id => "0"}
    assert e.save
    e.reload
    assert_equal "0", e.custom_value_for(field).value
  end

  def test_system_activity_with_child_in_use_should_be_in_use
    project = Project.generate!
    system_activity = TimeEntryActivity.create!(:name => 'Activity')
    project_activity = TimeEntryActivity.create!(:name => 'Activity', :project => project, :parent_id => system_activity.id)

    TimeEntry.generate!(:project => project, :activity => project_activity)

    assert project_activity.in_use?
    assert system_activity.in_use?
  end

  def test_destroying_a_system_activity_should_reassign_children_activities
    project = Project.generate!
    entries = []

    system_activity = TimeEntryActivity.create!(:name => 'Activity')
    entries << TimeEntry.generate!(:project => project, :activity => system_activity)
    
    project_activity = TimeEntryActivity.create!(:name => 'Activity', :project => project, :parent_id => system_activity.id)
    entries << TimeEntry.generate!(:project => project.reload, :activity => project_activity)

    assert_difference 'TimeEntryActivity.count', -2 do
      assert_nothing_raised do
        assert system_activity.destroy(TimeEntryActivity.find_by_name('Development'))
      end
    end
    assert entries.all? {|entry| entry.reload.activity.name == 'Development'}
  end

  def test_project_activity_without_parent_should_not_disable_system_activities
    project = Project.find(1)
    activity = TimeEntryActivity.create!(:name => 'Csutom', :project => project)
    assert_include activity, project.activities
    assert_include TimeEntryActivity.find(9), project.activities
  end
end
