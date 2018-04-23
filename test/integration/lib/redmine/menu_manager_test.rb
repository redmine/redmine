# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

require File.expand_path('../../../../test_helper', __FILE__)

class MenuManagerTest < Redmine::IntegrationTest
  include Redmine::I18n

  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules

  def test_project_menu_with_specific_locale
    get '/projects/ecookbook/issues',
      :headers => {'HTTP_ACCEPT_LANGUAGE' => 'fr,fr-fr;q=0.8,en-us;q=0.5,en;q=0.3'}

    assert_select 'div#main-menu' do
      assert_select 'li a.activity[href=?]', '/projects/ecookbook/activity', :text => ll('fr', :label_activity)
      assert_select 'li a.issues.selected[href=?]', '/projects/ecookbook/issues', :text => ll('fr', :label_issue_plural)
    end
  end

  def test_project_menu_with_additional_menu_items
    Setting.default_language = 'en'
    assert_no_difference 'Redmine::MenuManager.items(:project_menu).size' do
      Redmine::MenuManager.map :project_menu do |menu|
        menu.push :foo, { :controller => 'projects', :action => 'show' }, :caption => 'Foo'
        menu.push :bar, { :controller => 'projects', :action => 'show' }, :before => :activity
        menu.push :hello, { :controller => 'projects', :action => 'show' }, :caption => Proc.new {|p| p.name.upcase }, :after => :bar
      end

      get '/projects/ecookbook'

      assert_select 'div#main-menu ul' do
        assert_select 'li:last-child a.foo[href=?]', '/projects/ecookbook', :text => 'Foo'
        assert_select 'li:nth-child(2) a.bar[href=?]', '/projects/ecookbook', :text => 'Bar'
        assert_select 'li:nth-child(3) a.hello[href=?]', '/projects/ecookbook', :text => 'ECOOKBOOK'
        assert_select 'li:nth-child(4) a', :text => 'Activity'
      end

      # Remove the menu items
      Redmine::MenuManager.map :project_menu do |menu|
        menu.delete :foo
        menu.delete :bar
        menu.delete :hello
      end
    end
  end

  def test_main_menu_should_select_projects_tab_on_project_list
    get '/projects'
    assert_select '#main-menu' do
      assert_select 'a.projects'
      assert_select 'a.projects.selected'
    end
  end

  def test_main_menu_should_not_show_up_on_account
    get '/login'
    assert_select '#main-menu', 0
  end

  def test_body_should_have_main_menu_css_class_if_main_menu_is_present
    get '/projects'
    assert_select 'body.has-main-menu'
    get '/'
    assert_select 'body.has-main-menu', 0
  end
end
