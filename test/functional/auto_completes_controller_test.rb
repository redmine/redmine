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

require File.expand_path('../../test_helper', __FILE__)

class AutoCompletesControllerTest < Redmine::ControllerTest
  fixtures :projects, :issues, :issue_statuses,
           :enumerations, :users, :issue_categories,
           :trackers,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :journals, :journal_details

  def test_issues_should_not_be_case_sensitive
    get :issues, :params => {
        :project_id => 'ecookbook',
        :q => 'ReCiPe'
      }
    assert_response :success
    assert_include "recipe", response.body
  end

  def test_issues_should_accept_term_param
    get :issues, :params => {
        :project_id => 'ecookbook',
        :term => 'ReCiPe'
      }
    assert_response :success
    assert_include "recipe", response.body
  end

  def test_issues_should_return_issue_with_given_id
    get :issues, :params => {
        :project_id => 'subproject1',
        :q => '13'
      }
    assert_response :success
    assert_include "Bug #13", response.body
  end

  def test_issues_should_return_issue_with_given_id_preceded_with_hash
    get :issues, :params => {
        :project_id => 'subproject1',
        :q => '#13'
      }
    assert_response :success
    assert_include "Bug #13", response.body
  end

  def test_auto_complete_with_scope_all_should_search_other_projects
    get :issues, :params => {
        :project_id => 'ecookbook',
        :q => '13',
        :scope => 'all'
      }
    assert_response :success
    assert_include "Bug #13", response.body
  end

  def test_auto_complete_without_project_should_search_all_projects
    get :issues, :params => {
        :q => '13'
      }
    assert_response :success
    assert_include "Bug #13", response.body
  end

  def test_auto_complete_without_scope_all_should_not_search_other_projects
    get :issues, :params => {
        :project_id => 'ecookbook',
        :q => '13'
      }
    assert_response :success
    assert_not_include "Bug #13", response.body
  end

  def test_issues_should_return_json
    get :issues, :params => {
        :project_id => 'subproject1',
        :q => '13'
      }
    assert_response :success
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Array, json
    issue = json.first
    assert_kind_of Hash, issue
    assert_equal 13, issue['id']
    assert_equal 13, issue['value']
    assert_equal 'Bug #13: Subproject issue two', issue['label']
  end

  def test_auto_complete_with_status_o_should_return_open_issues_only
    get :issues, :params => {
        :project_id => 'ecookbook',
        :q => 'issue',
        :status => 'o'
      }
    assert_response :success
    assert_include "Issue due today", response.body
    assert_not_include "closed", response.body
  end

  def test_auto_complete_with_status_c_should_return_closed_issues_only
    get :issues, :params => {
        :project_id => 'ecookbook',
        :q => 'issue',
        :status => 'c'
      }
    assert_response :success
    assert_include "closed", response.body
    assert_not_include "Issue due today", response.body
  end

  def test_auto_complete_with_issue_id_should_not_return_that_issue
    get :issues, :params => {
        :project_id => 'ecookbook',
        :q => 'issue',
        :issue_id => '12'
      }
    assert_response :success
    assert_include "issue", response.body
    assert_not_include "Bug #12: Closed issue on a locked version", response.body
  end

  def test_auto_complete_should_return_json_content_type_response
    get :issues, :params => {
        :project_id => 'subproject1',
        :q => '#13'
      }

    assert_response :success
    assert_include 'application/json', response.headers['Content-Type']
  end
end
