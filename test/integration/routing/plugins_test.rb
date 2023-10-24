# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2023  Jean-Philippe Lang
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
  setup do
    @tmp_plugins_path = Rails.root.join('tmp/test/plugins')

    @setup_plugin_paths = []
    @setup_plugin_paths << setup_plugin(
      :redmine_test_plugin_foo,
      "config/routes.rb" => <<~ROUTES_CONTENT,
        resources :plugin_articles, only: %i[index]
      ROUTES_CONTENT
      "app/controllers/plugin_articles_controller.rb" => <<~CONTROLLER_CONTENT
        class PluginArticlesController < ApplicationController
          def index
            render plain: "foo PluginArticlesController#index"
          end
        end
      CONTROLLER_CONTENT
    )
    @setup_plugin_paths << setup_plugin(
      :redmine_test_plugin_bar,
      "config/routes.rb" => <<~ROUTES_CONTENT,
        # same path helper name with foo's
        get '/bar_plugin_articles', as: :plugin_articles, to: 'bar_plugin_articles#index'
      ROUTES_CONTENT
      "app/controllers/bar_plugin_articles_controller.rb" => <<~CONTROLLER_CONTENT
        class BarPluginArticlesController < ApplicationController
          def index
            render plain: "bar BarPluginArticlesController#index"
          end
        end
      CONTROLLER_CONTENT
    )

    # Change plugin loader's directory for testing
    Redmine::PluginLoader.directory = @tmp_plugins_path
    Redmine::PluginLoader.load
    Redmine::PluginLoader.directories.each(&:run_initializer) # to define relative controllers
    RedmineApp::Application.instance.routes_reloader.reload!
  end

  teardown do
    FileUtils.rm_rf @tmp_plugins_path
    Redmine::PluginLoader.load
    RedmineApp::Application.instance.routes_reloader.reload!
  end

  def test_plugins
    should_route 'GET /plugin_articles' => 'plugin_articles#index'
    should_route 'GET /bar_plugin_articles' => 'bar_plugin_articles#index'
    assert_equal("/bar_plugin_articles", plugin_articles_path)
  end

  private

  def setup_plugin(plugin_name, **relative_path_to_content)
    Redmine::Plugin.directory = @tmp_plugins_path
    plugin_path =  Redmine::Plugin.directory / plugin_name.to_s
    plugin_path.mkpath
    (plugin_path / "init.rb").write(<<~INITRB)
      Redmine::Plugin.register :#{plugin_name} do
        name 'Test plugin #{plugin_name}'
        author 'Author name'
        description 'This is a plugin for Redmine test'
        version '0.0.1'
      end

      Pathname(__dir__).glob("app/**/*.rb").sort.each do |path|
        require path
      end
    INITRB

    relative_path_to_content.each do |relative_path, content|
      path = plugin_path / relative_path
      path.parent.mkpath
      path.write(content)
    end

    return plugin_path
  end
end
