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

require File.expand_path('../../../test_helper', __FILE__)

class Redmine::ApiTest::CustomFieldsTest < Redmine::ApiTest::Base
  fixtures :users, :custom_fields

  test "GET /custom_fields.xml should return custom fields" do
    get '/custom_fields.xml', {}, credentials('admin')
    assert_response :success
    assert_equal 'application/xml', response.content_type

    assert_select 'custom_fields' do
      assert_select 'custom_field' do
        assert_select 'name', :text => 'Database'
        assert_select 'id', :text => '2'
        assert_select 'customized_type', :text => 'issue'
        assert_select 'possible_values[type=array]' do
          assert_select 'possible_value>value', :text => 'PostgreSQL'
        end
        assert_select 'trackers[type=array]'
        assert_select 'roles[type=array]'
      end
    end
  end
end
