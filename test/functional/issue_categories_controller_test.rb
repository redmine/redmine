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

require_relative '../test_helper'

class IssueCategoriesControllerTest < Redmine::ControllerTest
  def setup
    User.current = nil
    @request.session[:user_id] = 2
  end

  def test_new
    @request.session[:user_id] = 2 # manager
    get(:new, :params => {:project_id => '1'})
    assert_response :success
    assert_select 'input[name=?]', 'issue_category[name]'
  end

  def test_new_from_issue_form
    @request.session[:user_id] = 2 # manager
    get(
      :new,
      :params => {
        :project_id => '1'
      },
      :xhr => true
    )
    assert_response :success
    assert_equal 'text/javascript', response.media_type
  end

  def test_create
    @request.session[:user_id] = 2 # manager
    assert_difference 'IssueCategory.count' do
      post(
        :create,
        :params => {
          :project_id => '1',
          :issue_category => {
            :name => 'New category'
          }
        }
      )
    end
    assert_redirected_to '/projects/ecookbook/settings/categories'
    category = IssueCategory.find_by_name('New category')
    assert_not_nil category
    assert_equal 1, category.project_id
  end

  def test_create_failure
    @request.session[:user_id] = 2
    post(
      :create,
      :params => {
        :project_id => '1',
        :issue_category => {
          :name => ''
        }
      }
    )
    assert_response :success
    assert_select_error /Name cannot be blank/i
  end

  def test_create_from_issue_form
    @request.session[:user_id] = 2 # manager
    assert_difference 'IssueCategory.count' do
      post(
        :create,
        :params => {
          :project_id => '1',
          :issue_category => {
            :name => 'New category'
          }
        },
        :xhr => true
      )
    end
    category = IssueCategory.order('id DESC').first
    assert_equal 'New category', category.name

    assert_response :success
    assert_equal 'text/javascript', response.media_type
  end

  def test_create_from_issue_form_with_failure
    @request.session[:user_id] = 2 # manager
    assert_no_difference 'IssueCategory.count' do
      post(
        :create,
        :params => {
          :project_id => '1',
          :issue_category => {
            :name => ''
          }
        },
        :xhr => true
      )
    end

    assert_response :success
    assert_equal 'text/javascript', response.media_type
    assert_include 'Name cannot be blank', response.body
  end

  def test_edit
    @request.session[:user_id] = 2
    get(:edit, :params => {:id => 2})
    assert_response :success
    assert_select 'input[name=?][value=?]', 'issue_category[name]', 'Recipes'
  end

  def test_update
    assert_no_difference 'IssueCategory.count' do
      put(
        :update,
        :params => {
          :id => 2,
          :issue_category => {
            :name => 'Testing'
          }
        }
      )
    end
    assert_redirected_to '/projects/ecookbook/settings/categories'
    assert_equal 'Testing', IssueCategory.find(2).name
  end

  def test_update_failure
    put(
      :update,
      :params => {
        :id => 2,
        :issue_category => {
          :name => ''
        }
      }
    )
    assert_response :success
    assert_select_error /Name cannot be blank/i
  end

  def test_update_not_found
    put(
      :update,
      :params => {
        :id => 97,
        :issue_category => {
          :name => 'Testing'
        }
      }
    )
    assert_response :not_found
  end

  def test_destroy_category_not_in_use
    delete(:destroy, :params => {:id => 2})
    assert_redirected_to '/projects/ecookbook/settings/categories'
    assert_nil IssueCategory.find_by_id(2)
  end

  def test_destroy_category_in_use
    delete(:destroy, :params => {:id => 1})
    assert_response :success
    assert_not_nil IssueCategory.find_by_id(1)
    assert_select 'select[name=?]', 'reassign_to_id'
  end

  def test_destroy_category_in_use_with_reassignment
    issue = Issue.where(:category_id => 1).first
    delete(
      :destroy,
      :params => {
        :id => 1,
        :todo => 'reassign',
        :reassign_to_id => 2
      }
    )
    assert_redirected_to '/projects/ecookbook/settings/categories'
    assert_nil IssueCategory.find_by_id(1)
    # check that the issue was reassign
    assert_equal 2, issue.reload.category_id
  end

  def test_destroy_category_in_use_without_reassignment
    issue = Issue.where(:category_id => 1).first
    delete(
      :destroy,
      :params => {
        :id => 1,
        :todo => 'nullify'
      }
    )
    assert_redirected_to '/projects/ecookbook/settings/categories'
    assert_nil IssueCategory.find_by_id(1)
    # check that the issue category was nullified
    assert_nil issue.reload.category_id
  end
end
