# encoding: utf-8
#
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

class PrincipalTest < ActiveSupport::TestCase
  fixtures :users, :projects, :members, :member_roles

  def test_active_scope_should_return_groups_and_active_users
    result = Principal.active.all
    assert_include Group.first, result
    assert_not_nil result.detect {|p| p.is_a?(User)}
    assert_nil result.detect {|p| p.is_a?(User) && !p.active?}
    assert_nil result.detect {|p| p.is_a?(AnonymousUser)}
  end

  def test_member_of_scope_should_return_the_union_of_all_members
    projects = Project.find_all_by_id(1, 2)
    assert_equal projects.map(&:principals).flatten.sort, Principal.member_of(projects).sort
  end

  def test_member_of_scope_should_be_empty_for_no_projects
    assert_equal [], Principal.member_of([]).sort
  end

  def test_not_member_of_scope_should_return_users_that_have_no_memberships
    projects = Project.find_all_by_id(1, 2)
    expected = (Principal.all - projects.map(&:memberships).flatten.map(&:principal)).sort
    assert_equal expected, Principal.not_member_of(projects).sort
  end

  def test_not_member_of_scope_should_be_empty_for_no_projects
    assert_equal [], Principal.not_member_of([]).sort
  end

  context "#like" do
    setup do
      Principal.create!(:login => 'login')
      Principal.create!(:login => 'login2')

      Principal.create!(:firstname => 'firstname')
      Principal.create!(:firstname => 'firstname2')

      Principal.create!(:lastname => 'lastname')
      Principal.create!(:lastname => 'lastname2')

      Principal.create!(:mail => 'mail@example.com')
      Principal.create!(:mail => 'mail2@example.com')

      @palmer = Principal.create!(:firstname => 'David', :lastname => 'Palmer')
    end

    should "search login" do
      results = Principal.like('login')

      assert_equal 2, results.count
      assert results.all? {|u| u.login.match(/login/) }
    end

    should "search firstname" do
      results = Principal.like('firstname')

      assert_equal 2, results.count
      assert results.all? {|u| u.firstname.match(/firstname/) }
    end

    should "search lastname" do
      results = Principal.like('lastname')

      assert_equal 2, results.count
      assert results.all? {|u| u.lastname.match(/lastname/) }
    end

    should "search mail" do
      results = Principal.like('mail')

      assert_equal 2, results.count
      assert results.all? {|u| u.mail.match(/mail/) }
    end

    should "search firstname and lastname" do
      results = Principal.like('david palm')

      assert_equal 1, results.count
      assert_equal @palmer, results.first
    end

    should "search lastname and firstname" do
      results = Principal.like('palmer davi')

      assert_equal 1, results.count
      assert_equal @palmer, results.first
    end
  end

  def test_like_scope_with_cyrillic_name
    user = User.generate!(:firstname => 'Соболев', :lastname => 'Денис')
    results = Principal.like('Собо')
    assert_equal 1, results.count
    assert_equal user, results.first
  end
end
