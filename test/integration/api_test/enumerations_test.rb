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

require_relative '../../test_helper'

class Redmine::ApiTest::EnumerationsTest < Redmine::ApiTest::Base
  test "GET /enumerations/issue_priorities.xml should return priorities" do
    get '/enumerations/issue_priorities.xml'
    assert_response :success
    assert_equal 'application/xml', response.media_type
    assert_select 'issue_priorities[type=array]' do
      assert_select 'issue_priority:nth-of-type(3)' do
        assert_select 'id', :text => '6'
        assert_select 'name', :text => 'High'
        assert_select 'active', :text => 'true'
      end
      assert_select 'issue_priority:nth-of-type(6)' do
        assert_select 'id', :text => '15'
        assert_select 'name', :text => 'Inactive Priority'
        assert_select 'active', :text => 'false'
      end
    end
  end

  test "GET /enumerations/invalid_subclass.xml should return 404" do
    get '/enumerations/invalid_subclass.xml'
    assert_response :not_found
    assert_equal 'application/xml', response.media_type
  end
end
