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

class RoutingIssueStatusesTest < Redmine::RoutingTest
  def test_issue_statuses
    should_route 'GET /issue_statuses' => 'issue_statuses#index'
    should_route 'POST /issue_statuses' => 'issue_statuses#create'
    should_route 'GET /issue_statuses/new' => 'issue_statuses#new'

    should_route 'GET /issue_statuses/1/edit' => 'issue_statuses#edit', :id => '1'
    should_route 'PUT /issue_statuses/1' => 'issue_statuses#update', :id => '1'
    should_route 'DELETE /issue_statuses/1' => 'issue_statuses#destroy', :id => '1'

    should_route 'POST /issue_statuses/update_issue_done_ratio' => 'issue_statuses#update_issue_done_ratio'
  end
end
