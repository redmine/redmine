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

require File.expand_path('../../test_helper', __FILE__)

class WelcomeControllerTest < Redmine::ControllerTest
  fixtures :projects, :news, :users, :members, :roles, :member_roles, :enabled_modules

  def setup
    Setting.default_language = 'en'
    User.current = nil
  end

  def test_index
    get :index
    assert_response :success
    assert_select 'h3', :text => 'Latest news'
  end

  def test_browser_language
    @request.env['HTTP_ACCEPT_LANGUAGE'] = 'fr,fr-fr;q=0.8,en-us;q=0.5,en;q=0.3'
    get :index
    assert_select 'html[lang=fr]'
  end

  def test_browser_language_alternate
    @request.env['HTTP_ACCEPT_LANGUAGE'] = 'zh-TW'
    get :index
    assert_select 'html[lang=zh-TW]'
  end

  def test_browser_language_alternate_not_valid
    @request.env['HTTP_ACCEPT_LANGUAGE'] = 'fr-CA'
    get :index
    assert_select 'html[lang=fr]'
  end

  def test_browser_language_should_be_ignored_with_force_default_language_for_anonymous
    @request.env['HTTP_ACCEPT_LANGUAGE'] = 'fr,fr-fr;q=0.8,en-us;q=0.5,en;q=0.3'
    with_settings :force_default_language_for_anonymous => '1' do
      get :index
      assert_select 'html[lang=en]'
    end
  end

  def test_user_language_should_be_used
    user = User.find(2).update_attribute :language, 'it'
    @request.session[:user_id] = 2
    @request.env['HTTP_ACCEPT_LANGUAGE'] = 'fr,fr-fr;q=0.8,en-us;q=0.5,en;q=0.3'
    with_settings :default_language => 'fi' do
      get :index
      assert_select 'html[lang=it]'
    end
  end

  def test_user_language_should_be_ignored_if_force_default_language_for_loggedin
    user = User.find(2).update_attribute :language, 'it'
    @request.session[:user_id] = 2
    @request.env['HTTP_ACCEPT_LANGUAGE'] = 'fr,fr-fr;q=0.8,en-us;q=0.5,en;q=0.3'
    with_settings :force_default_language_for_loggedin => '1', :default_language => 'fi' do
      get :index
      assert_select 'html[lang=fi]'
    end
  end

  def test_warn_on_leaving_unsaved_turn_on
    user = User.find(2)
    user.pref.warn_on_leaving_unsaved = '1'
    user.pref.save!
    @request.session[:user_id] = 2

    get :index
    assert_select 'script', :text => %r{warnLeavingUnsaved}
  end

  def test_warn_on_leaving_unsaved_turn_off
    user = User.find(2)
    user.pref.warn_on_leaving_unsaved = '0'
    user.pref.save!
    @request.session[:user_id] = 2

    get :index
    assert_select 'script', :text => %r{warnLeavingUnsaved}, :count => 0
  end

  def test_textarea_font_set_to_monospace
    user = User.find(1)
    user.pref.textarea_font = 'monospace'
    user.pref.save!
    @request.session[:user_id] = 1
    get :index
    assert_select 'body.textarea-monospace'
  end

  def test_textarea_font_set_to_proportional
    user = User.find(1)
    user.pref.textarea_font = 'proportional'
    user.pref.save!
    @request.session[:user_id] = 1
    get :index
    assert_select 'body.textarea-proportional'
  end

  def test_logout_link_should_post
    @request.session[:user_id] = 2

    get :index
    assert_select 'a[href="/logout"][data-method=post]', :text => 'Sign out'
  end

  def test_call_hook_mixed_in
    assert @controller.respond_to?(:call_hook)
  end

  def test_project_jump_box_should_escape_names_once
    Project.find(1).update_attribute :name, 'Foo & Bar'
    @request.session[:user_id] = 2

    get :index
    assert_select "#header #project-jump" do
      assert_select "a", :text => 'Foo & Bar'
    end
  end

  def test_api_offset_and_limit_without_params
    assert_equal [0, 25], @controller.api_offset_and_limit({})
  end

  def test_api_offset_and_limit_with_limit
    assert_equal [0, 30], @controller.api_offset_and_limit({:limit => 30})
    assert_equal [0, 100], @controller.api_offset_and_limit({:limit => 120})
    assert_equal [0, 25], @controller.api_offset_and_limit({:limit => -10})
  end

  def test_api_offset_and_limit_with_offset
    assert_equal [10, 25], @controller.api_offset_and_limit({:offset => 10})
    assert_equal [0, 25], @controller.api_offset_and_limit({:offset => -10})
  end

  def test_api_offset_and_limit_with_offset_and_limit
    assert_equal [10, 50], @controller.api_offset_and_limit({:offset => 10, :limit => 50})
  end

  def test_api_offset_and_limit_with_page
    assert_equal [0, 25], @controller.api_offset_and_limit({:page => 1})
    assert_equal [50, 25], @controller.api_offset_and_limit({:page => 3})
    assert_equal [0, 25], @controller.api_offset_and_limit({:page => 0})
    assert_equal [0, 25], @controller.api_offset_and_limit({:page => -2})
  end

  def test_api_offset_and_limit_with_page_and_limit
    assert_equal [0, 100], @controller.api_offset_and_limit({:page => 1, :limit => 100})
    assert_equal [200, 100], @controller.api_offset_and_limit({:page => 3, :limit => 100})
  end

  def test_unhautorized_exception_with_anonymous_should_redirect_to_login
    WelcomeController.any_instance.stubs(:index).raises(::Unauthorized)

    get :index
    assert_response 302
    assert_redirected_to('/login?back_url='+CGI.escape('http://test.host/'))
  end

  def test_unhautorized_exception_with_anonymous_and_xmlhttprequest_should_respond_with_401_to_anonymous
    WelcomeController.any_instance.stubs(:index).raises(::Unauthorized)

    @request.env["HTTP_X_REQUESTED_WITH"] = "XMLHttpRequest"
    get :index
    assert_response 401
  end
end
