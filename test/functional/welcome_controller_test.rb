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

class WelcomeControllerTest < ActionController::TestCase
  fixtures :projects, :news, :users, :members

  def setup
    User.current = nil
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:news)
    assert_not_nil assigns(:projects)
    assert !assigns(:projects).include?(Project.where(:is_public => false).first)
  end

  def test_browser_language
    Setting.default_language = 'en'
    @request.env['HTTP_ACCEPT_LANGUAGE'] = 'fr,fr-fr;q=0.8,en-us;q=0.5,en;q=0.3'
    get :index
    assert_equal :fr, @controller.current_language
  end

  def test_browser_language_alternate
    Setting.default_language = 'en'
    @request.env['HTTP_ACCEPT_LANGUAGE'] = 'zh-TW'
    get :index
    assert_equal :"zh-TW", @controller.current_language
  end

  def test_browser_language_alternate_not_valid
    Setting.default_language = 'en'
    @request.env['HTTP_ACCEPT_LANGUAGE'] = 'fr-CA'
    get :index
    assert_equal :fr, @controller.current_language
  end

  def test_robots
    get :robots
    assert_response :success
    assert_equal 'text/plain', @response.content_type
    assert @response.body.match(%r{^Disallow: /projects/ecookbook/issues\r?$})
  end

  def test_warn_on_leaving_unsaved_turn_on
    user = User.find(2)
    user.pref.warn_on_leaving_unsaved = '1'
    user.pref.save!
    @request.session[:user_id] = 2

    get :index
    assert_tag 'script',
      :attributes => {:type => "text/javascript"},
      :content => %r{warnLeavingUnsaved}
  end

  def test_warn_on_leaving_unsaved_turn_off
    user = User.find(2)
    user.pref.warn_on_leaving_unsaved = '0'
    user.pref.save!
    @request.session[:user_id] = 2

    get :index
    assert_no_tag 'script',
      :attributes => {:type => "text/javascript"},
      :content => %r{warnLeavingUnsaved}
  end

  def test_logout_link_should_post
    @request.session[:user_id] = 2

    get :index
    assert_select 'a[href=/logout][data-method=post]', :text => 'Sign out'
  end

  def test_call_hook_mixed_in
    assert @controller.respond_to?(:call_hook)
  end

  def test_project_jump_box_should_escape_names_once
    Project.find(1).update_attribute :name, 'Foo & Bar'
    @request.session[:user_id] = 2

    get :index
    assert_select "#header select" do
      assert_select "option", :text => 'Foo &amp; Bar'
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
