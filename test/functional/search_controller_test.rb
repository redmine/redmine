# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

class SearchControllerTest < ActionController::TestCase
  fixtures :projects, :enabled_modules, :roles, :users, :members, :member_roles,
           :issues, :trackers, :issue_statuses, :enumerations,
           :custom_fields, :custom_values,
           :repositories, :changesets

  def setup
    User.current = nil
  end

  def test_search_for_projects
    get :index
    assert_response :success
    assert_template 'index'

    get :index, :q => "cook"
    assert_response :success
    assert_template 'index'
    assert assigns(:results).include?(Project.find(1))
  end

  def test_search_all_projects
    get :index, :q => 'recipe subproject commit', :all_words => ''
    assert_response :success
    assert_template 'index'

    assert assigns(:results).include?(Issue.find(2))
    assert assigns(:results).include?(Issue.find(5))
    assert assigns(:results).include?(Changeset.find(101))
    assert_tag :dt, :attributes => { :class => /issue/ },
                    :child => { :tag => 'a',  :content => /Add ingredients categories/ },
                    :sibling => { :tag => 'dd', :content => /should be classified by categories/ }

    assert assigns(:results_by_type).is_a?(Hash)
    assert_equal 5, assigns(:results_by_type)['changesets']
    assert_tag :a, :content => 'Changesets (5)'
  end

  def test_search_issues
    get :index, :q => 'issue', :issues => 1
    assert_response :success
    assert_template 'index'

    assert_equal true, assigns(:all_words)
    assert_equal false, assigns(:titles_only)
    assert assigns(:results).include?(Issue.find(8))
    assert assigns(:results).include?(Issue.find(5))
    assert_tag :dt, :attributes => { :class => /issue closed/ },
                    :child => { :tag => 'a',  :content => /Closed/ }
  end

  def test_search_issues_should_search_notes
    Journal.create!(:journalized => Issue.find(2), :notes => 'Issue notes with searchkeyword')

    get :index, :q => 'searchkeyword', :issues => 1
    assert_response :success
    assert_include Issue.find(2), assigns(:results)
  end

  def test_search_issues_with_multiple_matches_in_journals_should_return_issue_once
    Journal.create!(:journalized => Issue.find(2), :notes => 'Issue notes with searchkeyword')
    Journal.create!(:journalized => Issue.find(2), :notes => 'Issue notes with searchkeyword')

    get :index, :q => 'searchkeyword', :issues => 1
    assert_response :success
    assert_include Issue.find(2), assigns(:results)
    assert_equal 1, assigns(:results).size
  end

  def test_search_issues_should_search_private_notes_with_permission_only
    Journal.create!(:journalized => Issue.find(2), :notes => 'Private notes with searchkeyword', :private_notes => true)
    @request.session[:user_id] = 2

    Role.find(1).add_permission! :view_private_notes
    get :index, :q => 'searchkeyword', :issues => 1
    assert_response :success
    assert_include Issue.find(2), assigns(:results)

    Role.find(1).remove_permission! :view_private_notes
    get :index, :q => 'searchkeyword', :issues => 1
    assert_response :success
    assert_not_include Issue.find(2), assigns(:results)
  end

  def test_search_all_projects_with_scope_param
    get :index, :q => 'issue', :scope => 'all'
    assert_response :success
    assert_template 'index'
    assert assigns(:results).present?
  end

  def test_search_my_projects
    @request.session[:user_id] = 2
    get :index, :id => 1, :q => 'recipe subproject', :scope => 'my_projects', :all_words => ''
    assert_response :success
    assert_template 'index'
    assert assigns(:results).include?(Issue.find(1))
    assert !assigns(:results).include?(Issue.find(5))
  end

  def test_search_my_projects_without_memberships
    # anonymous user has no memberships
    get :index, :id => 1, :q => 'recipe subproject', :scope => 'my_projects', :all_words => ''
    assert_response :success
    assert_template 'index'
    assert assigns(:results).empty?
  end

  def test_search_project_and_subprojects
    get :index, :id => 1, :q => 'recipe subproject', :scope => 'subprojects', :all_words => ''
    assert_response :success
    assert_template 'index'
    assert assigns(:results).include?(Issue.find(1))
    assert assigns(:results).include?(Issue.find(5))
  end

  def test_search_without_searchable_custom_fields
    CustomField.update_all "searchable = #{ActiveRecord::Base.connection.quoted_false}"

    get :index, :id => 1
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:project)

    get :index, :id => 1, :q => "can"
    assert_response :success
    assert_template 'index'
  end

  def test_search_with_searchable_custom_fields
    get :index, :id => 1, :q => "stringforcustomfield"
    assert_response :success
    results = assigns(:results)
    assert_not_nil results
    assert_equal 1, results.size
    assert results.include?(Issue.find(7))
  end

  def test_search_all_words
    # 'all words' is on by default
    get :index, :id => 1, :q => 'recipe updating saving', :all_words => '1'
    assert_equal true, assigns(:all_words)
    results = assigns(:results)
    assert_not_nil results
    assert_equal 1, results.size
    assert results.include?(Issue.find(3))
  end

  def test_search_one_of_the_words
    get :index, :id => 1, :q => 'recipe updating saving', :all_words => ''
    assert_equal false, assigns(:all_words)
    results = assigns(:results)
    assert_not_nil results
    assert_equal 3, results.size
    assert results.include?(Issue.find(3))
  end

  def test_search_titles_only_without_result
    get :index, :id => 1, :q => 'recipe updating saving', :titles_only => '1'
    results = assigns(:results)
    assert_not_nil results
    assert_equal 0, results.size
  end

  def test_search_titles_only
    get :index, :id => 1, :q => 'recipe', :titles_only => '1'
    assert_equal true, assigns(:titles_only)
    results = assigns(:results)
    assert_not_nil results
    assert_equal 2, results.size
  end

  def test_search_content
    Issue.update_all("description = 'This is a searchkeywordinthecontent'", "id=1")

    get :index, :id => 1, :q => 'searchkeywordinthecontent', :titles_only => ''
    assert_equal false, assigns(:titles_only)
    results = assigns(:results)
    assert_not_nil results
    assert_equal 1, results.size
  end

  def test_search_with_offset
    get :index, :q => 'coo', :offset => '20080806073000'
    assert_response :success
    results = assigns(:results)
    assert results.any?
    assert results.map(&:event_datetime).max < '20080806T073000'.to_time
  end

  def test_search_previous_with_offset
    get :index, :q => 'coo', :offset => '20080806073000', :previous => '1'
    assert_response :success
    results = assigns(:results)
    assert results.any?
    assert results.map(&:event_datetime).min >= '20080806T073000'.to_time
  end

  def test_search_with_invalid_project_id
    get :index, :id => 195, :q => 'recipe'
    assert_response 404
    assert_nil assigns(:results)
  end

  def test_quick_jump_to_issue
    # issue of a public project
    get :index, :q => "3"
    assert_redirected_to '/issues/3'

    # issue of a private project
    get :index, :q => "4"
    assert_response :success
    assert_template 'index'
  end

  def test_large_integer
    get :index, :q => '4615713488'
    assert_response :success
    assert_template 'index'
  end

  def test_tokens_with_quotes
    get :index, :id => 1, :q => '"good bye" hello "bye bye"'
    assert_equal ["good bye", "hello", "bye bye"], assigns(:tokens)
  end

  def test_results_should_be_escaped_once
    assert Issue.find(1).update_attributes(:subject => '<subject> escaped_once', :description => '<description> escaped_once')
    get :index, :q => 'escaped_once'
    assert_response :success
    assert_select '#search-results' do
      assert_select 'dt.issue a', :text => /&lt;subject&gt;/
      assert_select 'dd', :text => /&lt;description&gt;/
    end
  end

  def test_keywords_should_be_highlighted
    assert Issue.find(1).update_attributes(:subject => 'subject highlighted', :description => 'description highlighted')
    get :index, :q => 'highlighted'
    assert_response :success
    assert_select '#search-results' do
      assert_select 'dt.issue a span.highlight', :text => 'highlighted'
      assert_select 'dd span.highlight', :text => 'highlighted'
    end
  end
end
