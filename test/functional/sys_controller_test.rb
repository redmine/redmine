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

class SysControllerTest < Redmine::ControllerTest
  def setup
    Setting.sys_api_enabled = '1'
    Setting.enabled_scm = %w(Subversion Git)
  end

  def teardown
    Setting.clear_cache
  end

  def test_projects_with_repository_enabled
    get :projects
    assert_response :success
    assert_equal 'application/json', @response.media_type

    data = ActiveSupport::JSON.decode(response.body)

    assert_equal Project.active.has_module(:repository).count, data.size
    project = data.first
    assert project['identifier']
    assert project['is_public']

    assert_not_include 'extra-info', response.body
    assert_not_include 'extra_info', response.body
  end

  def test_create_project_repository
    assert_nil Project.find(4).repository

    post(
      :create_project_repository,
      :params => {
        :id => 4,
        :vendor => 'Subversion',
        :repository => {:url => 'file:///create/project/repository/subproject2'}
      }
    )
    assert_response :created
    assert_equal 'application/json', @response.media_type

    r = Project.find(4).repository
    assert r.is_a?(Repository::Subversion)
    assert_equal 'file:///create/project/repository/subproject2', r.url

    data = ActiveSupport::JSON.decode(response.body)
    assert data['repository-subversion']
    assert_equal r.id, data['repository-subversion']['id']
    assert_equal r.url, data['repository-subversion']['url']

    assert_not_include 'extra-info', response.body
    assert_not_include 'extra_info', response.body
  end

  def test_create_already_existing
    post(
      :create_project_repository,
      :params => {
        :id => 1,
        :vendor => 'Subversion',
        :repository => {:url => 'file:///create/project/repository/subproject2'}
      }
    )
    assert_response :conflict
  end

  def test_create_with_failure
    post(
      :create_project_repository,
      :params => {
        :id => 4,
        :vendor => 'Subversion',
        :repository => {:url => 'invalid url'}
      }
    )
    assert_response :unprocessable_content
  end

  def test_fetch_changesets
    Repository::Subversion.any_instance.expects(:fetch_changesets).twice.returns(true)
    get :fetch_changesets
    assert_response :success
  end

  def test_fetch_changesets_one_project_by_identifier
    Repository::Subversion.any_instance.expects(:fetch_changesets).once.returns(true)
    get :fetch_changesets, :params => {:id => 'ecookbook'}
    assert_response :success
  end

  def test_fetch_changesets_one_project_by_id
    Repository::Subversion.any_instance.expects(:fetch_changesets).once.returns(true)
    get :fetch_changesets, :params => {:id => '1'}
    assert_response :success
  end

  def test_fetch_changesets_unknown_project
    get :fetch_changesets, :params => {:id => 'unknown'}
    assert_response :not_found
  end

  def test_disabled_ws_should_respond_with_403_error
    with_settings :sys_api_enabled => '0' do
      get :projects
      assert_response :forbidden
      assert_include 'Access denied', response.body
    end
  end

  def test_api_key
    with_settings :sys_api_key => 'my_secret_key' do
      get :projects, :params => {:key => 'my_secret_key'}
      assert_response :success
    end
  end

  def test_wrong_key_should_respond_with_403_error
    with_settings :sys_api_enabled => 'my_secret_key' do
      get :projects, :params => {:key => 'wrong_key'}
      assert_response :forbidden
      assert_include 'Access denied', response.body
    end
  end

  def test_should_skip_verify_authenticity_token
    ActionController::Base.allow_forgery_protection = true
    assert_nothing_raised {test_create_project_repository}
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
end
