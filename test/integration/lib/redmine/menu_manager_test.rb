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

require_relative '../../../test_helper'

class MenuManagerTest < Redmine::IntegrationTest
  include Redmine::I18n

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
        menu.push(
          :foo,
          {:controller => 'projects', :action => 'show'},
          :caption => 'Foo'
        )
        menu.push(
          :bar,
          {:controller => 'projects', :action => 'show'},
          :before => :activity
        )
        menu.push(
          :hello,
          {:controller => 'projects', :action => 'show'},
          :caption => Proc.new {|p| p.name.upcase},
          :after => :bar
        )
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

  def test_project_menu_should_display_repository_tab_when_exists_repository
    project = Project.find('ecookbook')
    repos = project.repositories
    assert_equal true, repos.exists?

    log_user('jsmith', 'jsmith')

    assert_equal true, repos.exists?(:is_default => true)
    get '/projects/ecookbook'
    assert_select '#main-menu' do
      assert_select 'a.repository', :count => 1
    end

    repos.update_all(:is_default => false)
    assert_equal false, repos.exists?(:is_default => true)
    get '/projects/ecookbook'
    assert_select '#main-menu' do
      assert_select 'a.repository', :count => 1
    end

    repos.delete_all
    assert_equal false, repos.exists?
    get '/projects/ecookbook'
    assert_select '#main-menu' do
      assert_select 'a.repository', :count => 0
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

  def test_cross_project_menu_should_hide_item_if_module_is_not_enabled_for_any_project
    user = User.find_by_login('dlopper')
    assert_equal [1, 3, 4, 6], Project.visible(user).ids.sort

    # gantt and news are not enabled for any visible project
    Project.find(1).enabled_module_names = %w(issue_tracking calendar)
    Project.find(3).enabled_module_names = %w(time_tracking)
    EnabledModule.where(:project_id => [4, 6]).delete_all

    log_user('dlopper', 'foo')
    get '/projects'
    assert_select '#main-menu' do
      assert_select 'a.projects',     :count => 1
      assert_select 'a.activity',     :count => 1

      assert_select 'a.issues',       :count => 1 # issue_tracking
      assert_select 'a.time-entries', :count => 1 # time_tracking
      assert_select 'a.gantt',        :count => 0 # gantt
      assert_select 'a.calendar',     :count => 1 # calendar
      assert_select 'a.news',         :count => 0 # news
    end
    assert_select '#projects-index' do
      assert_select 'a.project',      :count => 4
    end
  end

  def test_cross_project_menu_should_link_to_global_activity
    log_user('dlopper', 'foo')
    get '/queries/3/edit'
    assert_select 'a.activity[href=?]', '/activity'
  end

  def test_project_menu_should_show_roadmap_if_subprojects_have_versions
    Version.delete_all
    # Create a version in the project "eCookbook Subproject 1"
    version = Version.generate!(project_id: 3)

    with_settings :display_subprojects_issues => '1' do
      get '/projects/ecookbook'
      assert_select '#main-menu a.roadmap'
    end

    with_settings :display_subprojects_issues => '0' do
      get '/projects/ecookbook'
      assert_select '#main-menu a.roadmap', 0
    end
  end

  def test_project_menu_should_show_roadmap_if_project_has_shared_version
    Version.delete_all
    project = Project.generate!(:parent_id => 2)

    Version.generate!(project_id: 2, sharing: 'tree')

    with_settings :display_subprojects_issues => '1' do
      get "/projects/#{project.id}"
      assert_select '#main-menu a.roadmap'
    end

    with_settings :display_subprojects_issues => '0' do
      get "/projects/#{project.id}"
      assert_select '#main-menu a.roadmap'
    end
  end
end
