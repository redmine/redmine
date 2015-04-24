# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

class LayoutTest < Redmine::IntegrationTest
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules

  test "browsing to a missing page should render the base layout" do
    get "/users/100000000"

    assert_response :not_found

    # UsersController uses the admin layout by default
    assert_select "#admin-menu", :count => 0
  end

  test "browsing to an unauthorized page should render the base layout" do
    log_user('jsmith','jsmith')

    get "/admin"
    assert_response :forbidden
    assert_select "#admin-menu", :count => 0
  end

  def test_top_menu_and_search_not_visible_when_login_required
    with_settings :login_required => '1' do
      get '/'
      assert_select "#top-menu > ul", 0
      assert_select "#quick-search", 0
    end
  end

  def test_top_menu_and_search_visible_when_login_not_required
    with_settings :login_required => '0' do
      get '/'
      assert_select "#top-menu > ul"
      assert_select "#quick-search"
    end
  end

  def test_wiki_formatter_header_tags
    Role.anonymous.add_permission! :add_issues

    get '/projects/ecookbook/issues/new'
    assert_select 'head script[src=?]', '/javascripts/jstoolbar/jstoolbar-textile.min.js'
  end

  def test_calendar_header_tags
    with_settings :default_language => 'fr' do
      get '/issues'
      assert_include "/javascripts/i18n/datepicker-fr.js", response.body
    end

    with_settings :default_language => 'en-GB' do
      get '/issues'
      assert_include "/javascripts/i18n/datepicker-en-GB.js", response.body
    end

    with_settings :default_language => 'en' do
      get '/issues'
      assert_not_include "/javascripts/i18n/datepicker", response.body
    end

    with_settings :default_language => 'es' do
      get '/issues'
      assert_include "/javascripts/i18n/datepicker-es.js", response.body
    end

    with_settings :default_language => 'es-PA' do
      get '/issues'
      # There is not datepicker-es-PA.js
      # https://github.com/jquery/jquery-ui/tree/1.11.4/ui/i18n
      assert_not_include "/javascripts/i18n/datepicker-es.js", response.body
    end

    with_settings :default_language => 'zh' do
      get '/issues'
      assert_include "/javascripts/i18n/datepicker-zh-CN.js", response.body
    end

    with_settings :default_language => 'zh-TW' do
      get '/issues'
      assert_include "/javascripts/i18n/datepicker-zh-TW.js", response.body
    end

    with_settings :default_language => 'pt' do
      get '/issues'
      assert_include "/javascripts/i18n/datepicker-pt.js", response.body
    end

    with_settings :default_language => 'pt-BR' do
      get '/issues'
      assert_include "/javascripts/i18n/datepicker-pt-BR.js", response.body
    end
  end

  def test_search_field_outside_project_should_link_to_global_search
    get '/'
    assert_select 'div#quick-search form[action="/search"]'
  end

  def test_search_field_inside_project_should_link_to_project_search
    get '/projects/ecookbook'
    assert_select 'div#quick-search form[action="/projects/ecookbook/search"]'
  end
end
