# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

class Redmine::ApiTest::RolesTest < Redmine::ApiTest::Base
  fixtures :roles

  test "GET /roles.xml should return the roles" do
    get '/roles.xml'

    assert_response :success
    assert_equal 'application/xml', @response.content_type

    assert_select 'roles role', 3
    assert_select 'roles[type=array] role id', :text => '2' do
      assert_select '~ name', :text => 'Developer'
    end
  end

  test "GET /roles.json should return the roles" do
    get '/roles.json'

    assert_response :success
    assert_equal 'application/json', @response.content_type

    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert_kind_of Array, json['roles']
    assert_equal 3, json['roles'].size
    assert_include({'id' => 2, 'name' => 'Developer'}, json['roles'])
  end

  test "GET /roles/:id.xml should return the role" do
    get '/roles/1.xml'

    assert_response :success
    assert_equal 'application/xml', @response.content_type

    assert_select 'role' do
      assert_select 'name', :text => 'Manager'
      assert_select 'assignable', :text => 'true'
      assert_select 'issues_visibility', :text => 'all'
      assert_select 'time_entries_visibility', :text => 'all'
      assert_select 'users_visibility', :text => 'all'

      assert_select 'role permissions[type=array]' do
        assert_select 'permission', Role.find(1).permissions.size
        assert_select 'permission', :text => 'view_issues'
      end
    end
  end
end
