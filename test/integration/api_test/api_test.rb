# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
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
  fixtures :users, :email_addresses, :members, :member_roles, :roles, :projects

  def test_api_should_work_with_protect_from_forgery
    ActionController::Base.allow_forgery_protection = true
    assert_difference('User.count') do
      post(
        '/users.xml',
        :params => {
          :user => {
            :login => 'foo', :firstname => 'Firstname', :lastname => 'Lastname',
            :mail => 'foo@example.net', :password => 'secret123'
          }
        },
        :headers => credentials('admin')
      )
      assert_response 201
    end
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  def test_json_datetime_format
    get '/users/1.json', :headers => credentials('admin')
    assert_include %Q|"created_on":"#{Time.zone.parse('2006-07-19T17:12:21Z').iso8601}"|, response.body
  end

  def test_xml_datetime_format
    get '/users/1.xml', :headers => credentials('admin')
    assert_include "<created_on>#{Time.zone.parse('2006-07-19T17:12:21Z').iso8601}</created_on>", response.body
  end

  def test_head_response_should_have_empty_body
    put '/users/7.xml', :params => {:user => {:login => 'foo'}}, :headers => credentials('admin')

    assert_response :no_content
    assert_equal '', response.body
  end

  def test_api_with_invalid_format_should_return_406
    get '/users/1', :headers => credentials('admin').merge({'Accept' => 'application/xml', 'Content-type' => 'application/xml'})

    assert_response :not_acceptable
    assert_equal "We couldn't handle your request, sorry. If you were trying to access the API, make sure to append .json or .xml to your request URL.\n", response.body
  end
end
