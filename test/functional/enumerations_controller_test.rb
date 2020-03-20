# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class EnumerationsControllerTest < Redmine::ControllerTest
  fixtures :enumerations, :issues, :users

  def setup
    @request.session[:user_id] = 1 # admin
  end

  def test_index
    get :index
    assert_response :success
    assert_select 'table.enumerations'
  end

  def test_index_should_require_admin
    @request.session[:user_id] = nil
    get :index
    assert_response 302
  end

  def test_new
    get :new, :params => {
        :type => 'IssuePriority'
      }
    assert_response :success

    assert_select 'input[name=?][value=?]', 'enumeration[type]', 'IssuePriority'
    assert_select 'input[name=?]', 'enumeration[name]'
  end

  def test_new_with_invalid_type_should_respond_with_404
    get :new, :params => {
        :type => 'UnknownType'
      }
    assert_response 404
  end

  def test_create
    assert_difference 'IssuePriority.count' do
      post :create, :params => {
          :enumeration => {
            :type => 'IssuePriority',
            :name => 'Lowest'
          }
        }
    end
    assert_redirected_to '/enumerations'
    e = IssuePriority.find_by_name('Lowest')
    assert_not_nil e
  end

  def test_create_with_custom_field_values
    custom_field = TimeEntryActivityCustomField.generate!
    assert_difference 'TimeEntryActivity.count' do
      post :create, :params => {
          :enumeration => {
            :type => 'TimeEntryActivity',
            :name => 'Sample',
            :custom_field_values => {custom_field.id.to_s => "sample"}
          }
        }
    end
    assert_redirected_to '/enumerations'
    assert_equal "sample", Enumeration.find_by(:name => 'Sample').custom_field_values.last.value
  end

  def test_create_with_multiple_select_list_custom_fields
    custom_field = IssuePriorityCustomField.generate!(:field_format => 'list', :multiple => true, :possible_values => ['1', '2', '3', '4'])
    assert_difference 'IssuePriority.count' do
      post :create, :params => {
          :enumeration => {
            :type => 'IssuePriority',
            :name => 'Sample',
            :custom_field_values => {custom_field.id.to_s => ['1', '2']}
          }
        }
    end
    assert_redirected_to '/enumerations'
    assert_equal ['1', '2'].sort, Enumeration.find_by(:name => 'Sample').custom_field_values.last.value.sort
  end

  def test_create_with_failure
    assert_no_difference 'IssuePriority.count' do
      post :create, :params => {
          :enumeration => {
            :type => 'IssuePriority',
            :name => ''
          }
        }
    end
    assert_response :success
    assert_select_error /name cannot be blank/i
  end

  def test_edit
    get :edit, :params => {
        :id => 6
      }
    assert_response :success
    assert_select 'input[name=?][value=?]', 'enumeration[name]', 'High'
  end

  def test_edit_invalid_should_respond_with_404
    get :edit, :params => {
        :id => 999
      }
    assert_response 404
  end

  def test_update
    assert_no_difference 'IssuePriority.count' do
      put :update, :params => {
          :id => 6,
          :enumeration => {
            :type => 'IssuePriority',
            :name => 'New name'
          }
        }
    end
    assert_redirected_to '/enumerations'
    e = IssuePriority.find(6)
    assert_equal 'New name', e.name
  end

  def test_update_with_failure
    assert_no_difference 'IssuePriority.count' do
      put :update, :params => {
          :id => 6,
          :enumeration => {
            :type => 'IssuePriority',
            :name => ''
          }
        }
    end
    assert_response :success
    assert_select_error /name cannot be blank/i
  end

  def test_update_position
    assert_equal 2, Enumeration.find(2).position
    put :update, :params => {
          :id => 2,
          :enumeration => {
            :position => 1,
        }
      }
    assert_response 302
    assert_equal 1, Enumeration.find(2).position
  end

  def test_update_custom_field_values
    custom_field = TimeEntryActivityCustomField.generate!
    enumeration = Enumeration.find(9)
    assert_nil enumeration.custom_field_values.last.value
    put :update, :params => {
          :id => enumeration.id,
          :enumeration => {
            :custom_field_values => {custom_field.id.to_s => "sample"}
        }
      }
    assert_response 302
    assert_equal "sample", enumeration.reload.custom_field_values.last.value
  end

  def test_destroy_enumeration_not_in_use
    assert_difference 'IssuePriority.count', -1 do
      delete :destroy, :params => {
          :id => 7
        }
    end
    assert_redirected_to :controller => 'enumerations', :action => 'index'
    assert_nil Enumeration.find_by_id(7)
  end

  def test_destroy_enumeration_in_use
    assert_no_difference 'IssuePriority.count' do
      delete :destroy, :params => {
          :id => 4
        }
    end
    assert_response :success

    assert_not_nil Enumeration.find_by_id(4)
    assert_select 'select[name=reassign_to_id]' do
      assert_select 'option[value="6"]', :text => 'High'
    end
  end

  def test_destroy_enumeration_in_use_with_reassignment
    issue = Issue.where(:priority_id => 4).first
    assert_difference 'IssuePriority.count', -1 do
      delete :destroy, :params => {
          :id => 4,
          :reassign_to_id => 6
        }
    end
    assert_redirected_to :controller => 'enumerations', :action => 'index'
    assert_nil Enumeration.find_by_id(4)
    # check that the issue was reassign
    assert_equal 6, issue.reload.priority_id
  end

  def test_destroy_enumeration_in_use_with_blank_reassignment
    assert_no_difference 'IssuePriority.count' do
      delete :destroy, :params => {
          :id => 4,
          :reassign_to_id => ''
        }
    end
    assert_response :success
  end
end
