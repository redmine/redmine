# redMine - project management software
# Copyright (C) 2008  FreeCode
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

require File.dirname(__FILE__) + '/../test_helper'

class GroupTest < ActiveSupport::TestCase
  fixtures :groups, :users, :projects, :roles, :members
  
  def test_should_validate_presence_of_name
    g = Group.new(:name => '')
    assert !g.save
    assert_equal 1, g.errors.size
  end
  
  def test_should_validate_uniqueness_of_name
    g = Group.new(:name => groups(:clients).name)
    assert !g.save
    assert_equal 1, g.errors.size
  end
  
  def test_should_create
    g = Group.new(:name => 'New group')
    assert g.save
    assert g.users.empty?
  end
  
  def test_should_destroy
    g = groups(:clients)
    p = Project.find(1)
    u = users(:client)    
    assert u.member_of?(p)
    
    assert_difference('Member.count', -2) do
      g.destroy
    end
    u.reload
    assert_nil u.group
    assert !u.member_of?(p)
  end
  
  def test_should_add_user_to_group
    g = groups(:clients)
    p = Project.find(1)
    u = users(:new_client)
    r = roles(:reporter)
    assert !u.member_of?(p)
        
    assert_difference('Member.count') do
      assert_difference('g.reload.users.size') do
        u.group_id = g.id
        assert u.save
      end
    end
    u.reload
    assert u.group = g
    assert u.member_of?(p)
    assert_equal r, u.role_for_project(p)
  end
  
  def test_should_add_group_to_project
    g = groups(:clients)
    p = Project.find(2)
    u = users(:client)
    r = roles(:reporter)
    assert !u.member_of?(p)
        
    assert_difference('Member.count', 2) do
      assert_difference('p.reload.users.size') do
        m = Member.new(:project => p, :principal => g, :role => r)
        assert m.save
      end
    end
    u.reload
    assert u.member_of?(p)
    assert_equal r, u.role_for_project(p)
  end
  
  def test_should_remove_user_from_group
    g = groups(:clients)
    p = Project.find(1)
    u = users(:client)
    assert u.member_of?(p)

    assert_difference('Member.count', -1) do
      assert_difference('g.reload.users.size', -1) do
        u.group_id = nil
        assert u.save
      end
    end
  end
  
  def test_should_override_group_role
    g = groups(:clients)
    p = Project.find(1)
    u = users(:client)
    assert u.member_of?(p)
    assert_equal roles(:reporter), u.role_for_project(p)
    
    assert_difference('Member.count', 1) do
      assert_difference('p.reload.users.size', 0) do
        m = Member.new(:project => p, :principal => u, :role => roles(:manager))
        assert m.save
      end
    end
    assert_equal roles(:manager), u.reload.role_for_project(p)
    
    # Remove the group, user should still be a member
    assert_difference('Member.count', -2) do
      assert_difference('p.reload.users.size', 0) do
        assert g.destroy
      end
    end
    assert_equal roles(:manager), u.reload.role_for_project(p)
  end
end
