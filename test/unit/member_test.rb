# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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
    @jsmith = Member.find(1)
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
    # same use can't have more than one membership for a project
    assert !member.save

    # must have one role at least
    user = User.new(:firstname => "new1", :lastname => "user1", :mail => "test_validate@somenet.foo")
    user.login = "test_validate"
    user.password, user.password_confirmation = "password", "password"
    assert user.save

    set_language_if_valid 'fr'
    member = Member.new(:project_id => 1, :user_id => user.id, :role_ids => [])
    assert !member.save
    assert_include I18n.translate('activerecord.errors.messages.empty'), member.errors[:role]
    str = "R\xc3\xb4le doit \xc3\xaatre renseign\xc3\xa9(e)"
    str.force_encoding('UTF-8') if str.respond_to?(:force_encoding)
    assert_equal str, [member.errors.full_messages].flatten.join
  end

  def test_validate_member_role
    user = User.new(:firstname => "new1", :lastname => "user1", :mail => "test_validate@somenet.foo")
    user.login = "test_validate_member_role"
    user.password, user.password_confirmation = "password", "password"
    assert user.save
    member = Member.new(:project_id => 1, :user_id => user.id, :role_ids => [5])
    assert !member.save
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
end
