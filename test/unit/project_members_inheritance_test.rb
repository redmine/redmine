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

class ProjectMembersInheritanceTest < ActiveSupport::TestCase
  fixtures :roles, :users,
           :projects, :trackers, :issue_statuses

  def setup
    @parent = Project.generate!
    @member = Member.create!(:principal => User.find(2), :project => @parent, :role_ids => [1, 2])
    assert_equal 2, @member.reload.roles.size
  end

  def test_project_created_with_inherit_members_disabled_should_not_inherit_members
    assert_no_difference 'Member.count' do
      project = Project.generate_with_parent!(@parent, :inherit_members => false)

      assert_equal 0, project.memberships.count
    end
  end

  def test_project_created_with_inherit_members_should_inherit_members
    assert_difference 'Member.count', 1 do
      project = Project.generate_with_parent!(@parent, :inherit_members => true)
      project.reload

      assert_equal 1, project.memberships.count
      member = project.memberships.first
      assert_equal @member.principal, member.principal
      assert_equal @member.roles.sort, member.roles.sort
    end
  end

  def test_turning_on_inherit_members_should_inherit_members
    Project.generate_with_parent!(@parent, :inherit_members => false)

    assert_difference 'Member.count', 1 do
      project = Project.order('id desc').first
      project.inherit_members = true
      project.save!
      project.reload

      assert_equal 1, project.memberships.count
      member = project.memberships.first
      assert_equal @member.principal, member.principal
      assert_equal @member.roles.sort, member.roles.sort
    end
  end

  def test_turning_off_inherit_members_should_remove_inherited_members
    Project.generate_with_parent!(@parent, :inherit_members => true)

    assert_difference 'Member.count', -1 do
      project = Project.order('id desc').first
      project.inherit_members = false
      project.save!
      project.reload

      assert_equal 0, project.memberships.count
    end
  end

  def test_moving_a_root_project_under_a_parent_should_inherit_members
    Project.generate!(:inherit_members => true)
    project = Project.order('id desc').first

    assert_difference 'Member.count', 1 do
      project.set_parent!(@parent)
      project.reload

      assert_equal 1, project.memberships.count
      member = project.memberships.first
      assert_equal @member.principal, member.principal
      assert_equal @member.roles.sort, member.roles.sort
    end
  end

  def test_moving_a_subproject_as_root_should_loose_inherited_members
    Project.generate_with_parent!(@parent, :inherit_members => true)
    project = Project.order('id desc').first

    assert_difference 'Member.count', -1 do
      project.set_parent!(nil)
      project.reload

      assert_equal 0, project.memberships.count
    end
  end

  def test_moving_a_subproject_to_another_parent_should_change_inherited_members
    other_parent = Project.generate!
    other_member = Member.create!(:principal => User.find(4), :project => other_parent, :role_ids => [3])
    other_member.reload

    Project.generate_with_parent!(@parent, :inherit_members => true)
    project = Project.order('id desc').first
    project.set_parent!(other_parent.reload)
    project.reload

    assert_equal 1, project.memberships.count
    member = project.memberships.first
    assert_equal other_member.principal, member.principal
    assert_equal other_member.roles.sort, member.roles.sort
  end

  def test_inheritance_should_propagate_to_subprojects
    project = Project.generate_with_parent!(@parent, :inherit_members => false)
    subproject = Project.generate_with_parent!(project, :inherit_members => true)
    project.reload

    assert_difference 'Member.count', 2 do
      project.inherit_members = true
      project.save
      project.reload
      subproject.reload

      assert_equal 1, project.memberships.count
      assert_equal 1, subproject.memberships.count
      member = subproject.memberships.first
      assert_equal @member.principal, member.principal
      assert_equal @member.roles.sort, member.roles.sort
    end
  end

  def test_inheritance_removal_should_propagate_to_subprojects
    project = Project.generate_with_parent!(@parent, :inherit_members => true)
    subproject = Project.generate_with_parent!(project, :inherit_members => true)
    project.reload

    assert_difference 'Member.count', -2 do
      project.inherit_members = false
      project.save
      project.reload
      subproject.reload

      assert_equal 0, project.memberships.count
      assert_equal 0, subproject.memberships.count
    end
  end

  def test_adding_a_member_should_propagate
    project = Project.generate_with_parent!(@parent, :inherit_members => true)

    assert_difference 'Member.count', 2 do
      member = Member.create!(:principal => User.find(4), :project => @parent, :role_ids => [1, 3])
      member.reload

      inherited_member = project.memberships.order('id desc').first
      assert_equal member.principal, inherited_member.principal
      assert_equal member.roles.sort, inherited_member.roles.sort
    end
  end

  def test_adding_a_member_should_not_propagate_if_child_does_not_inherit
    project = Project.generate_with_parent!(@parent, :inherit_members => false)

    assert_difference 'Member.count', 1 do
      member = Member.create!(:principal => User.find(4), :project => @parent, :role_ids => [1, 3])

      assert_nil project.reload.memberships.detect {|m| m.principal == member.principal}
    end
  end

  def test_removing_a_member_should_propagate
    project = Project.generate_with_parent!(@parent, :inherit_members => true)

    assert_difference 'Member.count', -2 do
      @member.reload.destroy
      project.reload

      assert_equal 0, project.memberships.count
    end
  end

  def test_adding_a_group_member_should_propagate_with_its_users
    project = Project.generate_with_parent!(@parent, :inherit_members => true)
    group = Group.generate!
    user = User.find(4)
    group.users << user

    assert_difference 'Member.count', 4 do
      assert_difference 'MemberRole.count', 8 do
        member = Member.create!(:principal => group, :project => @parent, :role_ids => [1, 3])
        project.reload
        member.reload

        inherited_group_member = project.memberships.detect {|m| m.principal == group}
        assert_not_nil inherited_group_member
        assert_equal member.roles.sort, inherited_group_member.roles.sort

        inherited_user_member = project.memberships.detect {|m| m.principal == user}
        assert_not_nil inherited_user_member
        assert_equal member.roles.sort, inherited_user_member.roles.sort
      end
    end
  end

  def test_removing_a_group_member_should_propagate
    project = Project.generate_with_parent!(@parent, :inherit_members => true)
    group = Group.generate!
    user = User.find(4)
    group.users << user
    member = Member.create!(:principal => group, :project => @parent, :role_ids => [1, 3])

    assert_difference 'Member.count', -4 do
      assert_difference 'MemberRole.count', -8 do
        member.destroy
        project.reload

        inherited_group_member = project.memberships.detect {|m| m.principal == group}
        assert_nil inherited_group_member

        inherited_user_member = project.memberships.detect {|m| m.principal == user}
        assert_nil inherited_user_member
      end
    end
  end

  def test_adding_user_who_use_is_already_a_member_to_parent_project_should_merge_roles
    project = Project.generate_with_parent!(@parent, :inherit_members => true)
    user = User.find(4)
    Member.create!(:principal => user, :project => project, :role_ids => [1, 2])

    assert_difference 'Member.count', 1 do
      Member.create!(:principal => User.find(4), :project => @parent.reload, :role_ids => [1, 3])

      member = project.reload.memberships.detect {|m| m.principal == user}
      assert_not_nil member
      assert_equal [1, 2, 3], member.roles.uniq.sort.map(&:id)
    end
  end

  def test_turning_on_inheritance_with_user_who_is_already_a_member_should_merge_roles
    project = Project.generate_with_parent!(@parent)
    user = @member.user
    Member.create!(:principal => user, :project => project, :role_ids => [1, 3])
    project.reload

    assert_no_difference 'Member.count' do
      project.inherit_members = true
      project.save!

      member = project.reload.memberships.detect {|m| m.principal == user}
      assert_not_nil member
      assert_equal [1, 2, 3], member.roles.uniq.sort.map(&:id)
    end
  end
end
