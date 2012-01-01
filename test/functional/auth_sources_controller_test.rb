# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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

class AuthSourcesControllerTest < ActionController::TestCase
  fixtures :users

  def setup
    @request.session[:user_id] = 1
  end

  def test_index
    get :index

    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:auth_sources)
  end

  def test_new
    get :new

    assert_response :success
    assert_template 'new'
    assert_kind_of AuthSource, assigns(:auth_source)
    assert assigns(:auth_source).new_record?
  end

  def test_create
    assert_difference 'AuthSource.count' do
      post :create, :auth_source => {:name => 'Test'}
    end

    assert_redirected_to '/auth_sources'
    auth_source = AuthSource.first(:order => 'id DESC')
    assert_equal 'Test', auth_source.name
  end

  def test_edit
    auth_source = AuthSource.generate!(:name => 'TestEdit')
    get :edit, :id => auth_source.id

    assert_response :success
    assert_template 'edit'
    assert_equal auth_source, assigns(:auth_source)
  end

  def test_update
    auth_source = AuthSource.generate!(:name => 'TestEdit')
    post :update, :id => auth_source.id, :auth_source => {:name => 'TestUpdate'}

    assert_redirected_to '/auth_sources'
    assert_equal 'TestUpdate', auth_source.reload.name
  end

  def test_destroy_without_users
    auth_source = AuthSource.generate!(:name => 'TestEdit')
    assert_difference 'AuthSource.count', -1 do
      post :destroy, :id => auth_source.id
    end

    assert_redirected_to '/auth_sources'
  end

  def test_destroy_with_users
    auth_source = AuthSource.generate!(:name => 'TestEdit')
    User.generate!(:auth_source => auth_source)
    assert_no_difference 'AuthSource.count' do
      post :destroy, :id => auth_source.id
    end

    assert_redirected_to '/auth_sources'
    assert AuthSource.find(auth_source.id)
  end
end
