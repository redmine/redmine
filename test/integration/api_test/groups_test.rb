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

require File.expand_path('../../../test_helper', __FILE__)

class Redmine::ApiTest::GroupsTest < Redmine::ApiTest::Base
  fixtures :users, :groups_users, :email_addresses

  test "GET /groups.xml should require authentication" do
    get '/groups.xml'
    assert_response 401
  end

  test "GET /groups.xml should return givable groups" do
    get '/groups.xml', :headers => credentials('admin')
    assert_response :success
    assert_equal 'application/xml', response.media_type

    assert_select 'groups' do
      assert_select 'group', Group.givable.count
      assert_select 'group' do
        assert_select 'name', :text => 'A Team'
        assert_select 'id', :text => '10'
      end
    end
  end

  test "GET /groups.xml?builtin=1 should return all groups" do
    get '/groups.xml?builtin=1', :headers => credentials('admin')
    assert_response :success
    assert_equal 'application/xml', response.media_type

    assert_select 'groups' do
      assert_select 'group', Group.givable.count + 2
      assert_select 'group' do
        assert_select 'builtin', :text => 'non_member'
        assert_select 'id', :text => '12'
      end
      assert_select 'group' do
        assert_select 'builtin', :text => 'anonymous'
        assert_select 'id', :text => '13'
      end
    end
  end

  test "GET /groups.json should require authentication" do
    get '/groups.json'
    assert_response 401
  end

  test "GET /groups.json should return groups" do
    get '/groups.json', :headers => credentials('admin')
    assert_response :success
    assert_equal 'application/json', response.media_type

    json = ActiveSupport::JSON.decode(response.body)
    groups = json['groups']
    assert_kind_of Array, groups
    group = groups.detect {|g| g['name'] == 'A Team'}
    assert_not_nil group
    assert_equal({'id' => 10, 'name' => 'A Team'}, group)
  end

  test "GET /groups/:id.xml should return the group" do
    get '/groups/10.xml', :headers => credentials('admin')
    assert_response :success
    assert_equal 'application/xml', response.media_type

    assert_select 'group' do
      assert_select 'name', :text => 'A Team'
      assert_select 'id', :text => '10'
    end
  end

  test "GET /groups/:id.xml should return the builtin group" do
    get '/groups/12.xml', :headers => credentials('admin')
    assert_response :success
    assert_equal 'application/xml', response.media_type

    assert_select 'group' do
      assert_select 'builtin', :text => 'non_member'
      assert_select 'id', :text => '12'
    end
  end

  test "GET /groups/:id.xml should include users if requested" do
    get '/groups/10.xml?include=users', :headers => credentials('admin')
    assert_response :success
    assert_equal 'application/xml', response.media_type

    assert_select 'group' do
      assert_select 'users' do
        assert_select 'user', Group.find(10).users.count
        assert_select 'user[id="8"]'
      end
    end
  end

  test "GET /groups/:id.xml include memberships if requested" do
    get '/groups/10.xml?include=memberships', :headers => credentials('admin')
    assert_response :success
    assert_equal 'application/xml', response.media_type

    assert_select 'group' do
      assert_select 'memberships'
    end
  end

  test "POST /groups.xml with valid parameters should create the group" do
    assert_difference('Group.count') do
      post(
        '/groups.xml',
        :params => {:group => {:name => 'Test', :user_ids => [2, 3]}},
        :headers => credentials('admin')
      )
      assert_response :created
      assert_equal 'application/xml', response.media_type
    end

    group = Group.order('id DESC').first
    assert_equal 'Test', group.name
    assert_equal [2, 3], group.users.map(&:id).sort

    assert_select 'group' do
      assert_select 'name', :text => 'Test'
    end
  end

  test "POST /groups.xml with invalid parameters should return errors" do
    assert_no_difference('Group.count') do
      post(
        '/groups.xml',
        :params => {:group => {:name => ''}},
        :headers => credentials('admin')
      )
    end
    assert_response :unprocessable_entity
    assert_equal 'application/xml', response.media_type

    assert_select 'errors' do
      assert_select 'error', :text => /Name cannot be blank/
    end
  end

  test "PUT /groups/:id.xml with valid parameters should update the group" do
    group = Group.generate!
    put(
      "/groups/#{group.id}.xml",
      :params => {:group => {:name => 'New name', :user_ids => [2, 3]}},
      :headers => credentials('admin')
    )
    assert_response :no_content
    assert_equal '', @response.body

    assert_equal 'New name', group.reload.name
    assert_equal [2, 3], group.users.map(&:id).sort
  end

  test "PUT /groups/:id.xml with invalid parameters should return errors" do
    group = Group.generate!
    put(
      "/groups/#{group.id}.xml",
      :params => {:group => {:name => ''}},
      :headers => credentials('admin')
    )
    assert_response :unprocessable_entity
    assert_equal 'application/xml', response.media_type

    assert_select 'errors' do
      assert_select 'error', :text => /Name cannot be blank/
    end
  end

  test "DELETE /groups/:id.xml should delete the group" do
    group = Group.generate!
    assert_difference 'Group.count', -1 do
      delete "/groups/#{group.id}.xml", :headers => credentials('admin')
      assert_response :no_content
      assert_equal '', @response.body
    end
  end

  test "POST /groups/:id/users.xml should add user to the group" do
    group = Group.generate!
    assert_difference 'group.reload.users.count' do
      post(
        "/groups/#{group.id}/users.xml",
        :params => {:user_id => 5},
        :headers => credentials('admin')
      )
      assert_response :no_content
      assert_equal '', @response.body
    end
    assert_include User.find(5), group.reload.users
  end

  test "POST /groups/:id/users.xml should not add the user if already added" do
    group = Group.generate!
    group.users << User.find(5)

    assert_no_difference 'group.reload.users.count' do
      post(
        "/groups/#{group.id}/users.xml",
        :params => {:user_id => 5},
        :headers => credentials('admin')
      )
      assert_response :unprocessable_entity
    end

    assert_select 'errors' do
      assert_select 'error', :text => /User is invalid/
    end
  end

  test "DELETE /groups/:id/users/:user_id.xml should remove user from the group" do
    group = Group.generate!
    group.users << User.find(8)

    assert_difference 'group.reload.users.count', -1 do
      delete "/groups/#{group.id}/users/8.xml", :headers => credentials('admin')
      assert_response :no_content
      assert_equal '', @response.body
    end
    assert_not_include User.find(8), group.reload.users
  end
end
