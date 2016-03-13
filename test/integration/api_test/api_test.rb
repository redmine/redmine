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

require File.expand_path('../../../test_helper', __FILE__)

class Redmine::ApiTest::ApiTest < Redmine::ApiTest::Base
  fixtures :users

  def test_api_should_work_with_protect_from_forgery
    ActionController::Base.allow_forgery_protection = true
    assert_difference('User.count') do
      post '/users.xml', {
        :user => {
          :login => 'foo', :firstname => 'Firstname', :lastname => 'Lastname',
          :mail => 'foo@example.net', :password => 'secret123'}
        },
        credentials('admin')
      assert_response 201
    end
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  def test_json_datetime_format
    get '/users/1.json', {}, credentials('admin')
    assert_include '"created_on":"2006-07-19T17:12:21Z"', response.body
  end

  def test_xml_datetime_format
    get '/users/1.xml', {}, credentials('admin')
    assert_include '<created_on>2006-07-19T17:12:21Z</created_on>', response.body
  end
end
