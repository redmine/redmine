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

class GroupTest < ActiveSupport::TestCase
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :groups_users

  include Redmine::I18n

  def test_create
    g = Group.new(:name => 'New group')
    assert g.save
    g.reload
    assert_equal 'New group', g.name
  end

  def test_name_should_accept_255_characters
    name = 'a' * 255
    g = Group.new(:name => name)
    assert g.save
    g.reload
    assert_equal name, g.name
  end

  def test_blank_name_error_message
    set_language_if_valid 'en'
    g = Group.new
    assert !g.save
    assert_include "Name cannot be blank", g.errors.full_messages
  end

  def test_blank_name_error_message_fr
    set_language_if_valid 'fr'
    str = "Nom doit \xc3\xaatre renseign\xc3\xa9(e)".force_encoding('UTF-8')
    g = Group.new
    assert !g.save
    assert_include str, g.errors.full_messages
  end

  def test_group_roles_should_be_given_to_added_user
    group = Group.find(11)
    user = User.find(9)
    project = Project.first

    Member.create!(:principal => group, :project => project, :role_ids => [1, 2])
    group.users << user
    assert user.member_of?(project)
  end

  def test_new_roles_should_be_given_to_existing_user
    group = Group.find(11)
    user = User.find(9)
    project = Project.first

    group.users << user
    m = Member.create!(:principal => group, :project => project, :role_ids => [1, 2])
    assert user.member_of?(project)
  end

  def test_user_roles_should_updated_when_updating_user_ids
    group = Group.find(11)
    user = User.find(9)
    project = Project.first

    Member.create!(:principal => group, :project => project, :role_ids => [1, 2])
    group.user_ids = [user.id]
    group.save!
    assert User.find(9).member_of?(project)

    group.user_ids = [1]
    group.save!
    assert !User.find(9).member_of?(project)
  end

  def test_user_roles_should_updated_when_updating_group_roles
    group = Group.find(11)
    user = User.find(9)
    project = Project.first
    group.users << user
    m = Member.create!(:principal => group, :project => project, :role_ids => [1])
    assert_equal [1], user.reload.roles_for_project(project).collect(&:id).sort

    m.role_ids = [1, 2]
    assert_equal [1, 2], user.reload.roles_for_project(project).collect(&:id).sort

    m.role_ids = [2]
    assert_equal [2], user.reload.roles_for_project(project).collect(&:id).sort

    m.role_ids = [1]
    assert_equal [1], user.reload.roles_for_project(project).collect(&:id).sort
  end

  def test_user_memberships_should_be_removed_when_removing_group_membership
    assert User.find(8).member_of?(Project.find(5))
    Member.find_by_project_id_and_user_id(5, 10).destroy
    assert !User.find(8).member_of?(Project.find(5))
  end

  def test_user_roles_should_be_removed_when_removing_user_from_group
    assert User.find(8).member_of?(Project.find(5))
    User.find(8).groups = []
    assert !User.find(8).member_of?(Project.find(5))
  end

  def test_destroy_should_unassign_issues
    group = Group.find(10)
    Issue.where(:id => 1).update_all(["assigned_to_id = ?", group.id])

    assert group.destroy
    assert group.destroyed?

    assert_equal nil, Issue.find(1).assigned_to_id
  end

  def test_builtin_groups_should_be_created_if_missing
    Group.delete_all

    assert_difference 'Group.count', 2 do
      group = Group.anonymous
      assert_equal GroupAnonymous, group.class

      group = Group.non_member
      assert_equal GroupNonMember, group.class
    end
  end

  def test_builtin_in_group_should_be_uniq
    group = GroupAnonymous.new
    group.name = 'Foo'
    assert !group.save
  end

  def test_builtin_in_group_should_not_accept_users
    group = Group.anonymous
    assert_raise RuntimeError do
      group.users << User.find(1)
    end
    assert_equal 0, group.reload.users.count
  end

  def test_sorted_scope_should_sort_groups_alphabetically
    Group.delete_all
    b = Group.generate!(:name => 'B')
    a = Group.generate!(:name => 'A')

    assert_equal %w(A B), Group.sorted.to_a.map(&:name)
  end
end
