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

class Redmine::ApiTest::IssueCategoriesTest < Redmine::ApiTest::Base
  test "GET /projects/:project_id/issue_categories.xml should return the issue categories" do
    get '/projects/1/issue_categories.xml', :headers => credentials('jsmith')
    assert_response :success
    assert_equal 'application/xml', @response.media_type
    assert_select 'issue_categories issue_category id', :text => '2'
  end

  test "GET /issue_categories/:id.xml should return the issue category" do
    get '/issue_categories/2.xml', :headers => credentials('jsmith')
    assert_response :success
    assert_equal 'application/xml', @response.media_type
    assert_select 'issue_category id', :text => '2'
  end

  test "POST /projects/:project_id/issue_categories.xml should return create issue category" do
    assert_difference 'IssueCategory.count' do
      post(
        '/projects/1/issue_categories.xml',
        :params => {:issue_category => {:name => 'API'}},
        :headers => credentials('jsmith'))
    end
    assert_response :created
    assert_equal 'application/xml', @response.media_type

    category = IssueCategory.order('id DESC').first
    assert_equal 'API', category.name
    assert_equal 1, category.project_id
  end

  test "POST /projects/:project_id/issue_categories.xml with invalid parameters should return errors" do
    assert_no_difference 'IssueCategory.count' do
      post(
        '/projects/1/issue_categories.xml',
        :params => {:issue_category => {:name => ''}},
        :headers => credentials('jsmith'))
    end
    assert_response :unprocessable_content
    assert_equal 'application/xml', @response.media_type

    assert_select 'errors error', :text => "Name cannot be blank"
  end

  test "PUT /issue_categories/:id.xml with valid parameters should update the issue category" do
    assert_no_difference 'IssueCategory.count' do
      put(
        '/issue_categories/2.xml',
        :params => {:issue_category => {:name => 'API Update'}},
        :headers => credentials('jsmith'))
    end
    assert_response :no_content
    assert_equal '', @response.body
    assert_equal 'API Update', IssueCategory.find(2).name
  end

  test "PUT /issue_categories/:id.xml with invalid parameters should return errors" do
    assert_no_difference 'IssueCategory.count' do
      put(
        '/issue_categories/2.xml',
        :params => {:issue_category => {:name => ''}},
        :headers => credentials('jsmith'))
    end
    assert_response :unprocessable_content
    assert_equal 'application/xml', @response.media_type

    assert_select 'errors error', :text => "Name cannot be blank"
  end

  test "DELETE /issue_categories/:id.xml should destroy the issue category" do
    assert_difference 'IssueCategory.count', -1 do
      delete '/issue_categories/1.xml', :headers => credentials('jsmith')
    end
    assert_response :no_content
    assert_equal '', @response.body
    assert_nil IssueCategory.find_by_id(1)
  end

  test "DELETE /issue_categories/:id.xml should reassign issues with :reassign_to_id param" do
    issue_count = Issue.where(:category_id => 1).count
    assert issue_count > 0

    assert_difference 'IssueCategory.count', -1 do
      assert_difference 'Issue.where(:category_id => 2).count', 3 do
        delete(
          '/issue_categories/1.xml',
          :params => {:reassign_to_id => 2},
          :headers => credentials('jsmith'))
      end
    end
    assert_response :no_content
    assert_equal '', @response.body
    assert_nil IssueCategory.find_by_id(1)
  end
end
