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

class MemberTest < ActiveSupport::TestCase
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :groups_users,
           :watchers,
           :journals, :journal_details,
           :messages,
           :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions,
           :boards

  include Redmine::I18n

  def setup
    User.current = nil
    @jsmith = Member.find(1)
  end

  def test_sorted_scope_on_project_members
    members = Project.find(1).members.sorted.to_a
    roles = members.map {|m| m.roles.sort.first}
    assert_equal roles, roles.sort
  end

  def test_create
    member = Member.new(:project_id => 1, :user_id => 4, :role_ids => [1, 2])
    assert member.save
    member.reload

    assert_equal 2, member.roles.size
    assert_equal Role.find(1), member.roles.sort.first
  end

  def test_update
    assert_equal "eCookbook", @jsmith.project.name
    assert_equal "Manager", @jsmith.roles.first.name
    assert_equal "jsmith", @jsmith.user.login

    @jsmith.mail_notification = !@jsmith.mail_notification
    assert @jsmith.save
  end

  def test_update_roles
    assert_equal 1, @jsmith.roles.size
    @jsmith.role_ids = [1, 2]
    assert @jsmith.save
    assert_equal 2, @jsmith.reload.roles.size
  end

  def test_validate
    member = Member.new(:project_id => 1, :user_id => 2, :role_ids => [2])
    # same use cannot have more than one membership for a project
    assert !member.save

    # must have one role at least
    user = User.new(:firstname => "new1", :lastname => "user1",
                    :mail => "test_validate@somenet.foo")
    user.login = "test_validate"
    user.password, user.password_confirmation = "password", "password"
    assert user.save

    set_language_if_valid 'fr'
    member = Member.new(:project_id => 1, :user_id => user.id, :role_ids => [])
    assert !member.save
    assert_include I18n.translate('activerecord.errors.messages.empty'), member.errors[:role]
    assert_equal 'Rôle doit être renseigné(e)',
                 [member.errors.full_messages].flatten.join
  end

  def test_validate_member_role
    user = User.new(:firstname => "new1", :lastname => "user1",
                    :mail => "test_validate@somenet.foo")
    user.login = "test_validate_member_role"
    user.password, user.password_confirmation = "password", "password"
    assert user.save
    member = Member.new(:project_id => 1, :user_id => user.id, :role_ids => [5])
    assert !member.save
  end

  def test_set_issue_category_nil_should_handle_nil_values
    m = Member.new
    assert_nil m.user
    assert_nil m.project

    assert_nothing_raised do
      m.set_issue_category_nil
    end
  end

  def test_destroy
    category1 = IssueCategory.find(1)
    assert_equal @jsmith.user.id, category1.assigned_to_id
    assert_difference 'Member.count', -1 do
      assert_difference 'MemberRole.count', -1 do
        @jsmith.destroy
      end
    end
    assert_raise(ActiveRecord::RecordNotFound) { Member.find(@jsmith.id) }
    category1.reload
    assert_nil category1.assigned_to_id
  end

  def test_destroy_should_trigger_callbacks_only_once
    Member.class_eval { def destroy_test_callback; end}
    Member.after_destroy :destroy_test_callback

    m = Member.create!(:user_id => 1, :project_id => 1, :role_ids => [1,3])

    Member.any_instance.expects(:destroy_test_callback).once
    assert_difference 'Member.count', -1 do
      assert_difference 'MemberRole.count', -2 do
        m.destroy
      end
    end
    assert m.destroyed?
  ensure
    Member._destroy_callbacks.delete(:destroy_test_callback)
  end

  def test_roles_should_be_unique
    m = Member.new(:user_id => 1, :project_id => 1)
    m.member_roles.build(:role_id => 1)
    m.member_roles.build(:role_id => 1)
    m.save!
    m.reload
    assert_equal 1, m.roles.count
    assert_equal [1], m.roles.ids
  end

  def test_sort_without_roles
    a = Member.new(:roles => [Role.first])
    b = Member.new

    assert_equal -1, a <=> b
    assert_equal 1,  b <=> a
  end

  def test_sort_without_principal
    role = Role.first
    a = Member.new(:roles => [role], :principal => User.first)
    b = Member.new(:roles => [role])

    assert_equal -1, a <=> b
    assert_equal 1,  b <=> a
  end

  def test_managed_roles_should_return_all_roles_for_role_with_all_roles_managed
    member = Member.new
    member.roles << Role.generate!(:permissions => [:manage_members], :all_roles_managed => true)
    assert_equal Role.givable.all, member.managed_roles
  end

  def test_managed_roles_should_return_all_roles_for_admins
    member = Member.new(:user => User.find(1))
    member.roles << Role.generate!
    assert_equal Role.givable.all, member.managed_roles
  end

  def test_managed_roles_should_return_limited_roles_for_role_without_all_roles_managed
    member = Member.new
    member.roles << Role.generate!(:permissions => [:manage_members], :all_roles_managed => false, :managed_role_ids => [2, 3])
    assert_equal [2, 3], member.managed_roles.map(&:id).sort
  end

  def test_managed_roles_should_cumulated_managed_roles
    member = Member.new
    member.roles << Role.generate!(:permissions => [:manage_members], :all_roles_managed => false, :managed_role_ids => [3])
    member.roles << Role.generate!(:permissions => [:manage_members], :all_roles_managed => false, :managed_role_ids => [2])
    assert_equal [2, 3], member.managed_roles.map(&:id).sort
  end

  def test_managed_roles_should_return_no_roles_for_role_without_permission
    member = Member.new
    member.roles << Role.generate!(:all_roles_managed => true)
    assert_equal [], member.managed_roles
  end

  def test_create_principal_memberships_should_not_error_with_2_projects_and_inheritance
    parent = Project.generate!
    child = Project.generate!(:parent_id => parent.id, :inherit_members => true)
    user = User.generate!

    assert_difference 'Member.count', 2 do
      members = Member.create_principal_memberships(user, :project_ids => [parent.id, child.id], :role_ids => [1])
      assert members.none?(&:new_record?), "Unsaved members were returned: #{members.select(&:new_record?).map{|m| m.errors.full_messages}*","}"
    end
  end
end
