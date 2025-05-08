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

class TimeEntryActivityTest < ActiveSupport::TestCase
  include Redmine::I18n

  def setup
    User.current = nil
  end

  def test_should_be_an_enumeration
    assert TimeEntryActivity <= Enumeration
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
    project_activity =
      TimeEntryActivity.create!(:name => 'Activity', :project => project,
                                :parent_id => system_activity.id)
    TimeEntry.generate!(:project => project, :activity => project_activity)

    assert project_activity.in_use?
    assert system_activity.in_use?
  end

  def test_destroying_a_system_activity_should_reassign_children_activities
    project = Project.generate!
    entries = []
    system_activity = TimeEntryActivity.create!(:name => 'Activity')
    entries << TimeEntry.generate!(:project => project, :activity => system_activity)
    project_activity =
      TimeEntryActivity.create!(:name => 'Activity', :project => project,
                                :parent_id => system_activity.id)
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

  def test_project_activity_should_have_the_same_position_as_parent_activity
    project = Project.find(1)

    parent_activity = TimeEntryActivity.find_by(position: 3, parent_id: nil)
    project.update_or_create_time_entry_activities(
      {
        parent_activity.id.to_s => {
          'parent_id' => parent_activity.id.to_s,
          'active' => '0',
          'custom_field_values' => {'7' => '1'}
        }
      }
    )
    project_activity = TimeEntryActivity.find_by(position: 3, parent_id: parent_activity.id, project_id: 1)
    assert_equal parent_activity.position, project_activity.position

    # Changing the position of the parent activity also changes the position of the activity in each project.
    other_parent_activity = TimeEntryActivity.find_by(position: 4, parent_id: nil)
    project.update_or_create_time_entry_activities(
      {
        other_parent_activity.id.to_s => {
          'parent_id' => other_parent_activity.id.to_s,
          'active' => '0',
          'custom_field_values' => {'7' => '1'}
        }
      }
    )
    other_project_activity = TimeEntryActivity.find_by(position: 4, parent_id: other_parent_activity.id, project_id: 1)

    parent_activity.update(position: 4)
    assert_equal 4, parent_activity.reload.position
    assert_equal parent_activity.position, project_activity.reload.position
    assert_equal 3, other_parent_activity.reload.position
    assert_equal other_parent_activity.position, other_project_activity.reload.position
  end

  def test_project_activity_should_have_the_same_name_as_parent_activity
    parent_activity = TimeEntryActivity.find_by(name: 'Design', parent_id: nil)
    project = Project.find(1)
    project.update_or_create_time_entry_activities(
      {
        parent_activity.id.to_s => {
          'parent_id' => parent_activity.id.to_s,
          'active' => '0',
          'custom_field_values' => {'7' => '1'}
        }
      }
    )
    project_activity = TimeEntryActivity.find_by(name: 'Design', parent_id: parent_activity.id, project_id: project.id)
    assert_equal parent_activity.name, project_activity.name

    parent_activity.update(name: 'Design1')
    assert_equal parent_activity.reload.name, project_activity.reload.name

    # When changing the name of parent_activity,
    # if the name of parent_activity before the change and the name of project_activity do not match, the name of project_activity is not changed.
    project_activity.update(name: 'Design2')
    parent_activity.update(name: 'Design3')
    assert_equal 'Design2', project_activity.reload.name
    assert_equal 'Design3', parent_activity.reload.name
  end

  def test_project_activity_should_not_be_created_if_no_custom_value_is_changed
    system_activity = TimeEntryActivity.find(9) # Design
    assert_equal true, system_activity.active

    custom_field_value = system_activity.custom_field_values.detect{|cfv| cfv.custom_field.id == 7}
    assert_nil custom_field_value.value

    project = Project.find(1)
    assert_equal 0, project.time_entry_activities.count

    assert_no_difference 'TimeEntryActivity.count' do
      project.update_or_create_time_entry_activities(
        {
          '9' => {
            'parent_id' => '9',
            'active' => '1',
            'custom_field_values' => {'7' => ''}
          }
        }
      )
    end
  end

  def test_default_should_return_default_activity_if_default_activity_is_included_in_the_project_activities
    project = Project.find(1)
    assert_equal TimeEntryActivity.default(project).id, 10
  end

  def test_default_should_return_project_specific_default_activity_if_default_activity_is_not_included_in_the_project_activities
    project = Project.find(1)
    project_specific_default_activity = TimeEntryActivity.create!(name: 'Development', parent_id: 10, project_id: project.id, is_default: false)
    assert_not_equal TimeEntryActivity.default(project).id, 10
    assert_equal TimeEntryActivity.default(project).id, project_specific_default_activity.id
  end

  def test_default_activity_id_without_user_and_project_should_return_global_default_activity
    assert_equal 10, TimeEntryActivity.default_activity_id
  end

  def test_default_activity_id_with_user_and_project_should_return_role_default_activity
    # set a default activity for Manager role
    manager = Role.find(1)
    manager.default_time_entry_activity_id = 9
    manager.save

    assert_equal 9, TimeEntryActivity.default_activity_id(User.find(2), Project.find(1))
  end

  def test_default_activity_id_with_user_and_project_should_consider_role_position
    project = Project.find(1)
    user = User.find(2)

    # set a default activity for Manager role
    manager = Role.find(1)
    manager.default_time_entry_activity_id = 9
    manager.save!

    # set a default activity for Developer role
    # and set the role position first
    developer = Role.find(2)
    developer.default_time_entry_activity_id = 11
    developer.position = 1
    developer.save!

    member = Member.find_or_initialize_by(:project_id => project.id, :user_id => user.id)
    member.role_ids = [1, 2]
    member.save!

    assert_equal 11, TimeEntryActivity.default_activity_id(user, project)
  end

  def test_default_activity_id_should_include_only_available_activities
    # set a default activity for Manager role
    manager = Role.find(1)
    manager.default_time_entry_activity_id = 9
    manager.save!

    project = Project.find(1)

    # disable role default activity
    disable_activity = TimeEntryActivity.new({:name => "QA", :project => project, :parent => TimeEntryActivity.find(9), :active => false})
    disable_activity.save!

    assert_equal 10, TimeEntryActivity.default_activity_id(User.find(2), project)
  end

  def test_default_activity_id_should_selected_from_highest_priority_of_multiple_default_activity_candidates
    project = Project.find(1)

    manager = Role.find(1)
    manager.default_time_entry_activity_id = 9
    manager.save

    # Returns the role_default_activity with the highest priority
    assert_equal 9, TimeEntryActivity.default_activity_id(User.find(2), project)

    # Returns the child activity of role_default_activity if there is an activity that has the id of role_default_activity as parent_id
    design_project_activity = TimeEntryActivity.create!(name: 'Design', parent_id: 9, project_id: project.id, is_default: false)
    development_project_activity = TimeEntryActivity.create!(name: 'Development', parent_id: 10, project_id: project.id, is_default: true)
    qa_project_activity = TimeEntryActivity.create!(name: 'QA', parent_id: 11, project_id: project.id, is_default: false)
    assert_equal design_project_activity.id, TimeEntryActivity.default_activity_id(User.find(2), project)

    # Returns default project activity if role_default_activity is not present
    manager.default_time_entry_activity_id = nil
    manager.save
    assert_equal development_project_activity.id, TimeEntryActivity.default_activity_id(User.find(2), project)

    # Returns global default activity if role_default_activity and project activities are not present
    [design_project_activity, development_project_activity, qa_project_activity].each {|activity| activity.destroy}
    TimeEntryActivity.find(11).update(is_default: true)
    assert_equal 11, TimeEntryActivity.default_activity_id(User.find(2), project)

    # If there is only one activity available, it returns that activity.
    [TimeEntryActivity.find(10), TimeEntryActivity.find(11)].each {|a| a.update(active: false)}
    assert_equal 9, TimeEntryActivity.default_activity_id(User.find(2), project)
  end
end
