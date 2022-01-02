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

class Redmine::ApiTest::IssueStatusesTest < Redmine::ApiTest::Base
  fixtures :issue_statuses

  test "GET /issue_statuses.xml should return issue statuses" do
    get '/issue_statuses.xml'

    assert_response :success
    assert_equal 'application/xml', @response.media_type
    assert_select 'issue_statuses[type=array] issue_status id', :text => '2' do
      assert_select '~ name', :text => 'Assigned'
    end
  end
end
