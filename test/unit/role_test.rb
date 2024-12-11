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

class RoleTest < ActiveSupport::TestCase
  def setup
    User.current = nil
  end

  def test_sorted_scope
    assert_equal Role.all.sort, Role.sorted.to_a
  end

  def test_givable_scope
    assert_equal Role.all.reject(&:builtin?).sort, Role.givable.to_a
  end

  def test_builtin_scope
    assert_equal Role.all.select(&:builtin?).sort, Role.builtin(true).to_a.sort
    assert_equal Role.all.reject(&:builtin?).sort, Role.builtin(false).to_a.sort
  end

  def test_copy_from
    role = Role.find(1)
    copy = Role.new.copy_from(role)

    assert_nil copy.id
    assert_equal '', copy.name
    assert_equal role.permissions, copy.permissions

    copy.name = 'Copy'
    assert copy.save
  end

  def test_copy_from_should_copy_managed_roles
    orig = Role.generate!(:all_roles_managed => false, :managed_role_ids => [2, 3])
    role = Role.new
    role.copy_from orig
    assert_equal [2, 3], role.managed_role_ids.sort
  end

  def test_copy_workflows
    source = Role.find(1)
    rule_count = source.workflow_rules.count
    assert rule_count > 0

    target = Role.new(:name => 'Target')
    assert target.save
    target.copy_workflow_rules(source)
    target.reload
    assert_equal rule_count, target.workflow_rules.size
  end

  def test_permissions_should_be_unserialized_with_its_coder
    Role::PermissionsAttributeCoder.stubs(:load).returns([:foo, :bar])
    role = Role.find(1)
    assert_equal [:foo, :bar], role.permissions
  end

  def test_add_permission
    role = Role.find(1)
    size = role.permissions.size
    role.add_permission!("apermission", "anotherpermission")
    role.reload
    assert role.permissions.include?(:anotherpermission)
    assert_equal size + 2, role.permissions.size
  end

  def test_remove_permission
    role = Role.find(1)
    size = role.permissions.size
    perm = role.permissions[0..1]
    role.remove_permission!(*perm)
    role.reload
    assert ! role.permissions.include?(perm[0])
    assert_equal size - 2, role.permissions.size
  end

  def test_has_permission
    role = Role.create!(:name => 'Test', :permissions => [:view_issues, :edit_issues])
    assert_equal true, role.has_permission?(:view_issues)
    assert_equal false, role.has_permission?(:delete_issues)
  end

  def test_permissions_all_trackers?
    role = Role.create!(:name => 'Test', :permissions => [:view_issues])
    assert_equal true, role.permissions_all_trackers?(:view_issues)
    assert_equal false, role.permissions_all_trackers?(:edit_issues)

    role.set_permission_trackers :view_issues, [1]
    role.set_permission_trackers :edit_issues, [1]
    assert_equal false, role.permissions_all_trackers?(:view_issues)
    assert_equal false, role.permissions_all_trackers?(:edit_issues)

    role.set_permission_trackers :view_issues, :all
    role.set_permission_trackers :edit_issues, :all
    assert_equal true, role.permissions_all_trackers?(:view_issues)
    assert_equal false, role.permissions_all_trackers?(:edit_issues)
  end

  def test_permissions_all_trackers_considers_base_permission
    role = Role.create!(:name => 'Test', :permissions => [:view_issues])
    assert_equal true, role.permissions_all_trackers?(:view_issues)

    role.remove_permission!(:view_issues)
    assert_equal false, role.permissions_all_trackers?(:view_issues)
  end

  def test_permissions_tracker_ids?
    role = Role.create!(:name => 'Test', :permissions => [:view_issues])
    assert_equal false, role.permissions_tracker_ids?(:view_issues, 1)
    assert_equal false, role.permissions_tracker_ids?(:edit_issues, 1)

    role.set_permission_trackers :view_issues, [1, 2, 3]
    role.set_permission_trackers :edit_issues, [1, 2, 3]

    assert_equal true, role.permissions_tracker_ids?(:view_issues, 1)
    assert_equal false, role.permissions_tracker_ids?(:edit_issues, 1)
  end

  def test_permissions_tracker_ids_considers_base_permission
    role = Role.create!(:name => 'Test', :permissions => [:view_issues])
    role.set_permission_trackers :view_issues, [1, 2, 3]
    assert_equal true, role.permissions_tracker_ids?(:view_issues, 1)

    role.remove_permission!(:view_issues)
    assert_equal false, role.permissions_tracker_ids?(:view_issues, 1)
  end

  def test_permissions_tracker?
    tracker = Tracker.find(1)
    role = Role.create!(:name => 'Test', :permissions => [:view_issues])
    assert_equal true, role.permissions_tracker?(:view_issues, 1)
    assert_equal false, role.permissions_tracker?(:edit_issues, 1)

    role.set_permission_trackers :view_issues, [1]
    role.set_permission_trackers :edit_issues, [1]
    assert_equal true, role.permissions_tracker?(:view_issues, tracker)
    assert_equal false, role.permissions_tracker?(:edit_issues, tracker)

    role.set_permission_trackers :view_issues, [2]
    role.set_permission_trackers :edit_issues, [2]
    assert_equal false, role.permissions_tracker?(:view_issues, tracker)
    assert_equal false, role.permissions_tracker?(:edit_issues, tracker)

    role.set_permission_trackers :view_issues, :all
    role.set_permission_trackers :edit_issues, :all
    assert_equal true, role.permissions_tracker?(:view_issues, tracker)
    assert_equal false, role.permissions_tracker?(:edit_issues, tracker)
  end

  def test_permissions_tracker_considers_base_permission
    role = Role.create!(:name => 'Test', :permissions => [:edit_isues])
    role.set_permission_trackers :view_issues, [1, 2, 3]
    assert_equal false, role.permissions_tracker_ids?(:view_issues, 1)

    role.set_permission_trackers :view_issues, :all
    assert_equal false, role.permissions_tracker_ids?(:view_issues, 1)
  end

  def test_has_permission_without_permissions
    role = Role.create!(:name => 'Test')
    assert_equal false, role.has_permission?(:delete_issues)
  end

  def test_name
    I18n.locale = 'fr'
    assert_equal 'Manager', Role.find(1).name
    assert_equal 'Anonyme', Role.anonymous.name
    assert_equal 'Non membre', Role.non_member.name
  end

  def test_find_all_givable
    assert_equal Role.all.reject(&:builtin?).sort, Role.find_all_givable
  end

  def test_anonymous_should_return_the_anonymous_role
    assert_no_difference('Role.count') do
      role = Role.anonymous
      assert role.builtin?
      assert_equal Role::BUILTIN_ANONYMOUS, role.builtin
    end
  end

  def test_anonymous_with_a_missing_anonymous_role_should_return_the_anonymous_role
    Role.where(:builtin => Role::BUILTIN_ANONYMOUS).delete_all

    assert_difference('Role.count') do
      role = Role.anonymous
      assert role.builtin?
      assert_equal Role::BUILTIN_ANONYMOUS, role.builtin
    end
  end

  def test_non_member_should_return_the_non_member_role
    assert_no_difference('Role.count') do
      role = Role.non_member
      assert role.builtin?
      assert_equal Role::BUILTIN_NON_MEMBER, role.builtin
    end
  end

  def test_non_member_with_a_missing_non_member_role_should_return_the_non_member_role
    Role.where(:builtin => Role::BUILTIN_NON_MEMBER).delete_all

    assert_difference('Role.count') do
      role = Role.non_member
      assert role.builtin?
      assert_equal Role::BUILTIN_NON_MEMBER, role.builtin
    end
  end

  def test_destroy
    role = Role.generate!

    # generate some dependent objects
    query = IssueQuery.generate!(:project => @ecookbook, :visibility => Query::VISIBILITY_ROLES, :roles => Role.where(:id => [1, 3, role.id]).to_a)

    role.destroy

    # make sure some related data was removed
    assert_nil ActiveRecord::Base.connection.select_value("SELECT 1 FROM queries_roles WHERE role_id = #{role.id}")
    assert [1, 3], query.roles
  end
end
