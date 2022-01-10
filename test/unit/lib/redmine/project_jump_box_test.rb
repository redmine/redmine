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

require File.expand_path('../../../../test_helper', __FILE__)

class Redmine::ProjectJumpBoxTest < ActiveSupport::TestCase
  fixtures :users, :projects, :user_preferences, :members, :roles, :member_roles

  def setup
    @user = User.find_by_login 'jsmith'
    User.current = @user
    @ecookbook = Project.find 'ecookbook'
    @onlinestore = Project.find 'onlinestore'
  end

  def test_should_find_bookmarked_projects
    pjb = Redmine::ProjectJumpBox.new @user
    pjb.bookmark_project @ecookbook
    assert_equal 1, pjb.bookmarked_projects.size
  end

  def test_should_not_include_bookmark_in_recently_used_list
    pjb = Redmine::ProjectJumpBox.new @user
    pjb.project_used @ecookbook

    assert_equal 1, pjb.recently_used_projects.size

    pjb.bookmark_project @ecookbook
    assert_equal 0, pjb.recently_used_projects.size
  end

  def test_should_find_recently_used_projects
    pjb = Redmine::ProjectJumpBox.new @user
    pjb.project_used @ecookbook
    assert_equal 1, pjb.recently_used_projects.size
  end

  def test_should_limit_recently_used_projects
    pjb = Redmine::ProjectJumpBox.new @user
    pjb.project_used @ecookbook
    pjb.project_used Project.find 'onlinestore'

    @user.pref.recently_used_projects = 1

    assert_equal 1, pjb.recently_used_projects.size
  end

  def test_should_record_recently_used_projects_order
    pjb = Redmine::ProjectJumpBox.new @user
    other = Project.find 'onlinestore'
    pjb.project_used @ecookbook
    pjb.project_used other

    pjb = Redmine::ProjectJumpBox.new @user
    assert_equal 2, pjb.recently_used_projects.size
    assert_equal [other, @ecookbook], pjb.recently_used_projects

    pjb.project_used other

    pjb = Redmine::ProjectJumpBox.new @user
    assert_equal 2, pjb.recently_used_projects.size
    assert_equal [other, @ecookbook], pjb.recently_used_projects

    pjb.project_used @ecookbook
    pjb = Redmine::ProjectJumpBox.new @user
    assert_equal 2, pjb.recently_used_projects.size
    assert_equal [@ecookbook, other], pjb.recently_used_projects
  end

  def test_should_unbookmark_project
    pjb = Redmine::ProjectJumpBox.new @user
    assert pjb.bookmarked_projects.blank?

    # same instance should reflect new data
    pjb.bookmark_project @ecookbook
    assert pjb.bookmark?(@ecookbook)
    refute pjb.bookmark?(@onlinestore)
    assert_equal 1, pjb.bookmarked_projects.size
    assert_equal @ecookbook, pjb.bookmarked_projects.first

    # new instance should reflect new data as well
    pjb = Redmine::ProjectJumpBox.new @user
    assert pjb.bookmark?(@ecookbook)
    refute pjb.bookmark?(@onlinestore)
    assert_equal 1, pjb.bookmarked_projects.size
    assert_equal @ecookbook, pjb.bookmarked_projects.first

    pjb.bookmark_project @ecookbook
    pjb = Redmine::ProjectJumpBox.new @user
    assert_equal 1, pjb.bookmarked_projects.size
    assert_equal @ecookbook, pjb.bookmarked_projects.first

    pjb.delete_project_bookmark @onlinestore
    pjb = Redmine::ProjectJumpBox.new @user
    assert_equal 1, pjb.bookmarked_projects.size
    assert_equal @ecookbook, pjb.bookmarked_projects.first

    pjb.delete_project_bookmark @ecookbook
    pjb = Redmine::ProjectJumpBox.new @user
    assert pjb.bookmarked_projects.blank?
  end

  def test_should_update_recents_list
    pjb = Redmine::ProjectJumpBox.new @user
    assert pjb.recently_used_projects.blank?

    pjb.project_used @ecookbook
    pjb = Redmine::ProjectJumpBox.new @user
    assert_equal 1, pjb.recently_used_projects.size
    assert_equal @ecookbook, pjb.recently_used_projects.first

    pjb.project_used @ecookbook
    pjb = Redmine::ProjectJumpBox.new @user
    assert_equal 1, pjb.recently_used_projects.size
    assert_equal @ecookbook, pjb.recently_used_projects.first

    pjb.project_used @onlinestore
    assert_equal 2, pjb.recently_used_projects.size
    assert_equal @onlinestore, pjb.recently_used_projects.first
    assert_equal @ecookbook, pjb.recently_used_projects.last
  end

  def test_recents_list_should_include_only_visible_projects
    @user = User.find_by_login 'dlopper'
    User.current = @user

    pjb = Redmine::ProjectJumpBox.new @user
    pjb.project_used @ecookbook
    pjb.project_used @onlinestore

    assert_equal 1, pjb.recently_used_projects.size
    assert_equal @ecookbook, pjb.recently_used_projects.first
  end
end
