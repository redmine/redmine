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

class AdminControllerTest < ActionController::TestCase
  fixtures :projects, :users, :email_addresses, :roles

  def setup
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end

  def test_index
    get :index
    assert_select 'div.nodata', 0
  end

  def test_index_with_no_configuration_data
    delete_configuration_data
    get :index
    assert_select 'div.nodata'
  end

  def test_projects
    get :projects
    assert_response :success
    assert_template 'projects'
    assert_not_nil assigns(:projects)
    # active projects only
    assert_nil assigns(:projects).detect {|u| !u.active?}
  end

  def test_projects_with_status_filter
    get :projects, :status => 1
    assert_response :success
    assert_template 'projects'
    assert_not_nil assigns(:projects)
    # active projects only
    assert_nil assigns(:projects).detect {|u| !u.active?}
  end

  def test_projects_with_name_filter
    get :projects, :name => 'store', :status => ''
    assert_response :success
    assert_template 'projects'
    projects = assigns(:projects)
    assert_not_nil projects
    assert_equal 1, projects.size
    assert_equal 'OnlineStore', projects.first.name
  end

  def test_load_default_configuration_data
    delete_configuration_data
    post :default_configuration, :lang => 'fr'
    assert_response :redirect
    assert_nil flash[:error]
    assert IssueStatus.find_by_name('Nouveau')
  end

  def test_load_default_configuration_data_should_rescue_error
    delete_configuration_data
    Redmine::DefaultData::Loader.stubs(:load).raises(Exception.new("Something went wrong"))
    post :default_configuration, :lang => 'fr'
    assert_response :redirect
    assert_not_nil flash[:error]
    assert_match /Something went wrong/, flash[:error]
  end

  def test_test_email
    user = User.find(1)
    user.pref.no_self_notified = '1'
    user.pref.save!
    ActionMailer::Base.deliveries.clear

    get :test_email
    assert_redirected_to '/settings?tab=notifications'
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    user = User.find(1)
    assert_equal [user.mail], mail.bcc
  end

  def test_test_email_failure_should_display_the_error
    Mailer.stubs(:test_email).raises(Exception, 'Some error message')
    get :test_email
    assert_redirected_to '/settings?tab=notifications'
    assert_match /Some error message/, flash[:error]
  end

  def test_no_plugins
    Redmine::Plugin.stubs(:registered_plugins).returns({})

    get :plugins
    assert_response :success
    assert_template 'plugins'
    assert_equal [], assigns(:plugins)
  end

  def test_plugins
    # Register a few plugins
    Redmine::Plugin.register :foo do
      name 'Foo plugin'
      author 'John Smith'
      description 'This is a test plugin'
      version '0.0.1'
      settings :default => {'sample_setting' => 'value', 'foo'=>'bar'}, :partial => 'foo/settings'
    end
    Redmine::Plugin.register :bar do
    end

    get :plugins
    assert_response :success
    assert_template 'plugins'

    assert_select 'tr#plugin-foo' do
      assert_select 'td span.name', :text => 'Foo plugin'
      assert_select 'td.configure a[href="/settings/plugin/foo"]'
    end
    assert_select 'tr#plugin-bar' do
      assert_select 'td span.name', :text => 'Bar'
      assert_select 'td.configure a', 0
    end
  end

  def test_info
    get :info
    assert_response :success
    assert_template 'info'
  end

  def test_admin_menu_plugin_extension
    Redmine::MenuManager.map :admin_menu do |menu|
      menu.push :test_admin_menu_plugin_extension, '/foo/bar', :caption => 'Test'
    end

    get :index
    assert_response :success
    assert_select 'div#admin-menu a[href="/foo/bar"]', :text => 'Test'

    Redmine::MenuManager.map :admin_menu do |menu|
      menu.delete :test_admin_menu_plugin_extension
    end
  end

  private

  def delete_configuration_data
    Role.delete_all('builtin = 0')
    Tracker.delete_all
    IssueStatus.delete_all
    Enumeration.delete_all
  end
end
