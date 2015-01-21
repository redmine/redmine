# encoding: utf-8
#
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

class PrincipalTest < ActiveSupport::TestCase
  fixtures :users, :projects, :members, :member_roles, :roles,
           :email_addresses

  def test_active_scope_should_return_groups_and_active_users
    result = Principal.active.to_a
    assert_include Group.first, result
    assert_not_nil result.detect {|p| p.is_a?(User)}
    assert_nil result.detect {|p| p.is_a?(User) && !p.active?}
    assert_nil result.detect {|p| p.is_a?(AnonymousUser)}
  end

  def test_visible_scope_for_admin_should_return_all_principals
    admin = User.generate! {|u| u.admin = true}
    assert_equal Principal.count, Principal.visible(admin).count
  end

  def test_visible_scope_for_user_with_members_of_visible_projects_visibility_should_return_active_principals
    Role.non_member.update! :users_visibility => 'all'
    user = User.generate!

    expected = Principal.active
    assert_equal expected.map(&:id).sort, Principal.visible(user).pluck(:id).sort
  end

  def test_visible_scope_for_user_with_members_of_visible_projects_visibility_should_return_members_of_visible_projects_and_self
    Role.non_member.update! :users_visibility => 'members_of_visible_projects'
    user = User.generate!

    expected = Project.visible(user).map(&:member_principals).flatten.map(&:principal).uniq << user
    assert_equal expected.map(&:id).sort, Principal.visible(user).pluck(:id).sort
  end

  def test_member_of_scope_should_return_the_union_of_all_members
    projects = Project.find([1])
    assert_equal [3, 2], Principal.member_of(projects).sort.map(&:id)
    projects = Project.find([1, 2])
    assert_equal [3, 2, 8, 11], Principal.member_of(projects).sort.map(&:id)
  end

  def test_member_of_scope_should_be_empty_for_no_projects
    assert_equal [], Principal.member_of([]).sort
  end

  def test_not_member_of_scope_should_return_users_that_have_no_memberships
    [[1], [1, 2]].each do |ids|
      projects = Project.find(ids)
      assert_equal ids.size, projects.count
      expected = (Principal.all - projects.map(&:memberships).flatten.map(&:principal)).sort
      assert_equal expected, Principal.not_member_of(projects).sort
    end
  end

  def test_not_member_of_scope_should_be_empty_for_no_projects
    assert_equal [], Principal.not_member_of([]).sort
  end

  def test_sorted_scope_should_sort_users_before_groups
    scope = Principal.where(:type => ['User', 'Group'])
    users = scope.select {|p| p.is_a?(User)}.sort
    groups = scope.select {|p| p.is_a?(Group)}.sort

    assert_equal (users + groups).map(&:name).map(&:downcase),
                 scope.sorted.map(&:name).map(&:downcase)
  end

  test "like scope should search login" do
    results = Principal.like('jsmi')

    assert results.any?
    assert results.all? {|u| u.login.match(/jsmi/i) }
  end

  test "like scope should search firstname" do
    results = Principal.like('john')

    assert results.any?
    assert results.all? {|u| u.firstname.match(/john/i) }
  end

  test "like scope should search lastname" do
    results = Principal.like('smi')

    assert results.any?
    assert results.all? {|u| u.lastname.match(/smi/i) }
  end

  test "like scope should search mail" do
    results = Principal.like('somenet')

    assert results.any?
    assert results.all? {|u| u.mail.match(/somenet/i) }
  end

  test "like scope should search firstname and lastname" do
    results = Principal.like('john smi')

    assert_equal 1, results.count
    assert_equal User.find(2), results.first
  end

  test "like scope should search lastname and firstname" do
    results = Principal.like('smith joh')

    assert_equal 1, results.count
    assert_equal User.find(2), results.first
  end

  def test_like_scope_with_cyrillic_name
    user = User.generate!(:firstname => 'Соболев', :lastname => 'Денис')
    results = Principal.like('Собо')
    assert_equal 1, results.count
    assert_equal user, results.first
  end
end
