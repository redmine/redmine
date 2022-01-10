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

class ProjectEnumerationsControllerTest < Redmine::ControllerTest
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :custom_fields, :custom_fields_projects,
           :custom_fields_trackers, :custom_values,
           :time_entries

  self.use_transactional_tests = false

  def setup
    @request.session[:user_id] = nil
    Setting.default_language = 'en'
  end

  def test_update_to_override_system_activities
    @request.session[:user_id] = 2 # manager
    billable_field = TimeEntryActivityCustomField.find_by_name("Billable")

    put(
      :update,
      :params => {
        :project_id => 1,
        :enumerations => {
          "9"=> {"parent_id"=>"9", "custom_field_values"=> {"7" => "1"}, "active"=>"0"}, # Design, De-activate
          "10"=> {"parent_id"=>"10", "custom_field_values"=>{"7"=>"0"}, "active"=>"1"}, # Development, Change custom value
          "14"=>{"parent_id"=>"14", "custom_field_values"=>{"7"=>"1"}, "active"=>"1"}, # Inactive Activity, Activate with custom value
          "11"=>{"parent_id"=>"11", "custom_field_values"=>{"7"=>"1"}, "active"=>"1"} # QA, no changes
        }
      }
    )
    assert_response :redirect
    assert_redirected_to '/projects/ecookbook/settings/activities'

    # Created project specific activities...
    project = Project.find('ecookbook')

    # ... Design
    design = project.time_entry_activities.find_by_name("Design")
    assert design, "Project activity not found"

    assert_equal 9, design.parent_id # Relate to the system activity
    assert_not_equal design.parent.id, design.id # Different records
    assert_equal design.parent.name, design.name # Same name
    assert !design.active?

    # ... Development
    development = project.time_entry_activities.find_by_name("Development")
    assert development, "Project activity not found"

    assert_equal 10, development.parent_id # Relate to the system activity
    assert_not_equal development.parent.id, development.id # Different records
    assert_equal development.parent.name, development.name # Same name
    assert development.active?
    assert_equal "0", development.custom_value_for(billable_field).value

    # ... Inactive Activity
    previously_inactive = project.time_entry_activities.find_by_name("Inactive Activity")
    assert previously_inactive, "Project activity not found"

    assert_equal 14, previously_inactive.parent_id # Relate to the system activity
    assert_not_equal previously_inactive.parent.id, previously_inactive.id # Different records
    assert_equal previously_inactive.parent.name, previously_inactive.name # Same name
    assert previously_inactive.active?
    assert_equal "1", previously_inactive.custom_value_for(billable_field).value

    # ... QA
    assert_nil project.time_entry_activities.find_by_name("QA"), "Custom QA activity created when it wasn't modified"
  end

  def test_update_should_not_create_project_specific_activities_when_setting_empty_value_in_custom_field_with_default_value_of_nil
    system_activity = TimeEntryActivity.find(9) # Design
    custom_field_value = system_activity.custom_field_values.detect{|cfv| cfv.custom_field.id == 7}
    assert_nil custom_field_value.value

    assert_no_difference 'TimeEntryActivity.count' do
      @request.session[:user_id] = 2 # manager
      put(
        :update,
        :params => {
          :project_id => 1,
          :enumerations => {
            "9" => {"parent_id" => "9", "custom_field_values" => {"7" => ""}, "active" => "1"}
          }
        }
      )
      assert_response :redirect
    end
  end

  def test_update_will_update_project_specific_activities
    @request.session[:user_id] = 2 # manager

    project_activity = TimeEntryActivity.new({
                                               :name => 'Project Specific',
                                               :parent => TimeEntryActivity.first,
                                               :project => Project.find(1),
                                               :active => true
                                             })
    assert project_activity.save
    project_activity_two = TimeEntryActivity.new({
                                                   :name => 'Project Specific Two',
                                                   :parent => TimeEntryActivity.last,
                                                   :project => Project.find(1),
                                                   :active => true
                                                 })
    assert project_activity_two.save

    put(
      :update,
      :params => {
        :project_id => 1,
        :enumerations => {
          project_activity.id => {
            "custom_field_values"=> {"7" => "1"},
            "active"=>"0"
          }, # De-activate
          project_activity_two.id => {
            "custom_field_values"=>{"7" => "1"},
            "active"=>"0"
          } # De-activate
        }
      }
    )
    assert_response :redirect
    assert_redirected_to '/projects/ecookbook/settings/activities'

    # Created project specific activities...
    project = Project.find('ecookbook')
    assert_equal 2, project.time_entry_activities.count

    activity_one = project.time_entry_activities.find_by_name(project_activity.name)
    assert activity_one, "Project activity not found"
    assert_equal project_activity.id, activity_one.id
    assert !activity_one.active?

    activity_two = project.time_entry_activities.find_by_name(project_activity_two.name)
    assert activity_two, "Project activity not found"
    assert_equal project_activity_two.id, activity_two.id
    assert !activity_two.active?
  end

  def test_update_when_creating_new_activities_will_convert_existing_data
    assert_equal 3, TimeEntry.where(:activity_id => 9, :project_id => 1).count

    @request.session[:user_id] = 2 # manager
    put(
      :update,
      :params => {
        :project_id => 1,
        :enumerations => {
          "9"=> {
            "parent_id"=>"9",
              "custom_field_values"=> {
                "7" => "1"
              },
            "active"=>"0"
          } # Design, De-activate
        }
      }
    )
    assert_response :redirect

    # No more TimeEntries using the system activity
    assert_equal 0, TimeEntry.where(:activity_id => 9, :project_id => 1).count,
                 "Time Entries still assigned to system activities"
    # All TimeEntries using project activity
    project_specific_activity = TimeEntryActivity.find_by_parent_id_and_project_id(9, 1)
    assert_equal 3, TimeEntry.where(:activity_id => project_specific_activity.id,
                                    :project_id => 1).count,
                 "No Time Entries assigned to the project activity"
  end

  def test_update_when_creating_new_activities_will_not_convert_existing_data_if_an_exception_is_raised
    # TODO: Need to cause an exception on create but these tests
    # aren't setup for mocking.  Just create a record now so the
    # second one is a dupicate
    user = User.find(1)
    parent = TimeEntryActivity.find(9)
    TimeEntryActivity.create!({:name => parent.name, :project_id => 1,
                               :position => parent.position, :active => true, :parent_id => 9})
    TimeEntry.create!({:project_id => 1, :hours => 1.0, :user => user, :author => user,
                       :issue_id => 3, :activity_id => 10, :spent_on => '2009-01-01'})
    assert_equal 3, TimeEntry.where(:activity_id => 9, :project_id => 1).count
    assert_equal 1, TimeEntry.where(:activity_id => 10, :project_id => 1).count

    @request.session[:user_id] = 2 # manager
    put(
      :update, :params => {
        :project_id => 1,
        :enumerations => {
          # Design
          "9"=> {"parent_id"=>"9", "custom_field_values"=>{"7" => "1"}, "active"=>"0"},
          # Development, Change custom value
          "10"=> {"parent_id"=>"10", "custom_field_values"=>{"7"=>"0"}, "active"=>"1"}
        }
      }
    )
    assert_response :redirect

    # TimeEntries shouldn't have been reassigned on the failed record
    assert_equal 3, TimeEntry.where(:activity_id => 9,
                                    :project_id => 1).count,
                 "Time Entries are not assigned to system activities"
    # TimeEntries shouldn't have been reassigned on the saved record either
    assert_equal 1, TimeEntry.where(:activity_id => 10,
                                    :project_id => 1).count,
                 "Time Entries are not assigned to system activities"
  end

  def test_destroy
    @request.session[:user_id] = 2 # manager
    project_activity = TimeEntryActivity.new({
                                               :name => 'Project Specific',
                                               :parent => TimeEntryActivity.first,
                                               :project => Project.find(1),
                                               :active => true
                                             })
    assert project_activity.save
    project_activity_two = TimeEntryActivity.new({
                                                   :name => 'Project Specific Two',
                                                   :parent => TimeEntryActivity.last,
                                                   :project => Project.find(1),
                                                   :active => true
                                                 })
    assert project_activity_two.save

    delete(:destroy, :params => {:project_id => 1})
    assert_response :redirect
    assert_redirected_to '/projects/ecookbook/settings/activities'

    assert_nil TimeEntryActivity.find_by_id(project_activity.id)
    assert_nil TimeEntryActivity.find_by_id(project_activity_two.id)
  end

  def test_destroy_should_reassign_time_entries_back_to_the_system_activity
    @request.session[:user_id] = 2 # manager
    project_activity = TimeEntryActivity.new({
                                               :name => 'Project Specific Design',
                                               :parent => TimeEntryActivity.find(9),
                                               :project => Project.find(1),
                                               :active => true
                                             })
    assert project_activity.save
    assert TimeEntry.where(["project_id = ? AND activity_id = ?", 1, 9]).
             update_all("activity_id = '#{project_activity.id}'")
    assert_equal 3, TimeEntry.where(:activity_id => project_activity.id,
                                    :project_id => 1).count
    delete(:destroy, :params => {:project_id => 1})
    assert_response :redirect
    assert_redirected_to '/projects/ecookbook/settings/activities'

    assert_nil TimeEntryActivity.find_by_id(project_activity.id)
    assert_equal(
      0,
      TimeEntry.
        where(
          :activity_id => project_activity.id,
          :project_id => 1
        ).count,
      "TimeEntries still assigned to project specific activity"
    )
    assert_equal(
      3,
      TimeEntry.
        where(
          :activity_id => 9,
          :project_id => 1
        ).count,
      "TimeEntries still assigned to project specific activity"
    )
  end
end
