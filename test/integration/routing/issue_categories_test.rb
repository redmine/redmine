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

class RoutingIssueCategoriesTest < Redmine::RoutingTest
  def test_issue_categories_scoped_under_project
    should_route 'GET /projects/foo/issue_categories' => 'issue_categories#index', :project_id => 'foo'
    should_route 'GET /projects/foo/issue_categories/new' => 'issue_categories#new', :project_id => 'foo'
    should_route 'POST /projects/foo/issue_categories' => 'issue_categories#create', :project_id => 'foo'
  end

  def test_issue_categories
    should_route 'GET /issue_categories/1/edit' => 'issue_categories#edit', :id => '1'
    should_route 'PUT /issue_categories/1' => 'issue_categories#update', :id => '1'
    should_route 'DELETE /issue_categories/1' => 'issue_categories#destroy', :id => '1'
  end
end
