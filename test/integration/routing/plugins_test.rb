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

require File.expand_path('../../test_helper', __dir__)

class RoutingPluginsTest < Redmine::RoutingTest
  def setup
    @original_plugin_dir = Redmine::PluginLoader.directory

    Redmine::Plugin.clear
    Redmine::PluginLoader.directory = Rails.root.join('test/fixtures/plugins')
    Redmine::Plugin.directory = Rails.root.join('test/fixtures/plugins')
    Redmine::PluginLoader.load
    Redmine::PluginLoader.directories.each(&:run_initializer) # to define relative controllers
    RedmineApp::Application.instance.routes_reloader.reload!
  end

  def teardown
    Redmine::Plugin.clear
    Redmine::PluginLoader.directory = @original_plugin_dir
    Redmine::Plugin.directory = @original_plugin_dir
    Redmine::PluginLoader.load
    RedmineApp::Application.instance.routes_reloader.reload!
  end

  def test_plugins
    should_route 'GET /plugin_articles' => 'plugin_articles#index'
    should_route 'GET /bar_plugin_articles' => 'bar_plugin_articles#index'
    assert_equal("/bar_plugin_articles", plugin_articles_path)
    should_route(
      'GET /attachments/plugin_articles/12/edit' => 'attachments#edit_all',
      :object_id => '12',
      :object_type => 'plugin_articles'
    )
  end
end
