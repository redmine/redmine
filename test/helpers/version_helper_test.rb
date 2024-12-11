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

class VersionsHelperTest < Redmine::HelperTest
  def test_version_filtered_issues_path_sharing_none
    version = Version.new(:name => 'test', :sharing => 'none')
    version.project = Project.find(5)
    assert_match '/projects/private-child/issues?', version_filtered_issues_path(version)
  end

  def test_version_filtered_issues_path_sharing_descendants
    version = Version.new(:name => 'test', :sharing => 'descendants')
    version.project = Project.find(5)
    assert_match '/projects/private-child/issues?', version_filtered_issues_path(version)
  end

  def test_version_filtered_issues_path_sharing_hierarchy
    version = Version.new(:name => 'test', :sharing => 'hierarchy')
    version.project = Project.find(5)
    assert_match '/projects/private-child/issues?', version_filtered_issues_path(version)
  end

  def test_version_filtered_issues_path_sharing_tree
    version = Version.new(:name => 'test', :sharing => 'tree')
    version.project = Project.find(5)
    assert_match '/projects/ecookbook/issues?', version_filtered_issues_path(version)
  end

  def test_version_filtered_issues_path_sharing_tree_without_permission_to_root_project
    EnabledModule.where("name = 'issue_tracking' AND project_id = 1").delete_all
    version = Version.new(:name => 'test', :sharing => 'tree')
    version.project = Project.find(5)
    assert_no_match '/projects/ecookbook/issues?', version_filtered_issues_path(version)
    assert_match '/issues?', version_filtered_issues_path(version)
  end

  def test_version_filtered_issues_path_sharing_system
    version = Version.new(:name => 'test', :sharing => 'system')
    version.project = Project.find(5)
    assert_match /^\/issues\?/, version_filtered_issues_path(version)
  end

  def test_link_to_new_issue_should_return_link_to_add_issue
    version = Version.find(3)
    project = Project.find(1)
    User.current = User.find(1)

    # href should contain the following params:
    # fixed_version_id=3
    # tracker_id=1
    assert_select_in(
      link_to_new_issue(version, project),
      '[href=?]',
      '/projects/ecookbook/issues/new?back_url=' \
        '%2Fversions%2F3&issue%5Bfixed_version_id%5D=3&issue%5Btracker_id%5D=1',
      :text => 'New issue'
    )
  end

  def test_link_to_new_issue_should_return_nil_if_version_status_is_not_open
    # locked version
    version = Version.find(2)
    project = Project.find(1)
    User.current = User.find(1)

    assert_nil link_to_new_issue(version, project)
  end

  def test_link_to_new_issue_should_return_nil_if_user_does_not_have_permission_to_add_issue
    Role.find(1).remove_permission! :add_issues
    version = Version.find(3)
    project = Project.find(1)
    User.current = User.find(2)

    assert_nil link_to_new_issue(version, project)
  end

  def test_link_to_new_issue_should_return_nil_if_no_tracker_is_available_for_project
    trackers = Tracker::CORE_FIELDS - %w(fixed_version_id)
    # disable fixed_version_id field for all trackers
    Tracker.all.each do |tracker|
      tracker.core_fields = trackers
      tracker.save!
    end

    version = Version.find(3)
    project = Project.find(1)
    User.current = User.find(2)

    assert_nil link_to_new_issue(version, project)
  end

  def test_link_to_new_issue_should_take_into_account_user_permissions_on_fixed_version_id_field
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 1,
                               :old_status_id => 1,
                               :field_name => 'fixed_version_id',
                               :rule => 'readonly')
    version = Version.find(3)
    project = Project.find(1)
    User.current = User.find(2)

    # href should contain param tracker_id=2 because for tracker_id 1,
    # user has only readonly permissions on fixed_version_id
    assert_select_in(
      link_to_new_issue(version, project),
      '[href=?]',
      '/projects/ecookbook/issues/new?back_url=' \
        '%2Fversions%2F3&issue%5Bfixed_version_id%5D=3&issue%5Btracker_id%5D=2'
    )
  end
end
