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

class WebhooksControllerTest < Redmine::ControllerTest
  setup do
    @project = Project.find 'ecookbook'
    @dlopper = User.find_by_login 'dlopper'
    @issue = @project.issues.first
    @role = Role.find_by_name 'Developer'
    @role.permissions << :use_webhooks; @role.save!
    @hook = create_hook
    @other_hook = create_hook user: User.find_by_login('admin'), url: 'https://example.com/other/hook'
    @request.session[:user_id] = @dlopper.id
    @original_webhooks_setting = Setting.webhooks_enabled = '1'
  end

  teardown do
    Setting.webhooks_enabled = @original_webhooks_setting
  end

  test "should require login" do
    @request.session[:user_id] = nil
    get :index
    assert_redirected_to '/login?back_url=http%3A%2F%2Ftest.host%2Fwebhooks'
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_select 'td', text: @hook.url
    assert_select 'td', text: @other_hook.url, count: 0
  end

  test "should return not found when disabled" do
    with_settings webhooks_enabled: '0' do
      get :index
      assert_response :forbidden

      get :new
      assert_response :forbidden
    end
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create webhook" do
    assert_difference 'Webhook.count' do
      post :create, params: { webhook: { url: 'https://example.com/new/hook', events: %w(issue.created), project_ids: [@project.id] } }
    end
    assert_redirected_to webhooks_path
  end

  test "should get edit" do
    get :edit, params: { id: @hook.id }
    assert_response :success
  end

  test "should update webhook" do
    patch :update, params: { id: @hook.id, webhook: { url: 'https://example.com/updated/hook' } }
    assert_redirected_to webhooks_path
    assert_equal 'https://example.com/updated/hook', @hook.reload.url
  end

  test 'edit should not find hook of other user' do
    get :edit, params: { id: @other_hook.id }
    assert_response :not_found
  end

  private

  def create_hook(url: 'https://example.com/some/hook',
                  user: User.find_by_login('dlopper'),
                  events: %w(issue.created issue.updated),
                  projects: [Project.find('ecookbook')])
    Webhook.create!(url: url, user: user, events: events, projects: projects)
  end
end
