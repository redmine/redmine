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

require File.expand_path('../../../../test_helper', __FILE__)

class Redmine::PluginLoaderTest < ActiveSupport::TestCase
  def setup
    clear_public

    @klass = Redmine::PluginLoader
    @klass.directory = Rails.root.join('test/fixtures/plugins')
    @klass.public_directory = Rails.root.join('tmp/public/plugin_assets')
    @klass.load
  end

  def teardown
    clear_public
  end

  def test_create_assets_reloader
    plugin_assets = @klass.create_assets_reloader
    plugin_assets.execute.inspect

    assert File.exist?("#{@klass.public_directory}/foo_plugin")
    assert File.exist?("#{@klass.public_directory}/foo_plugin/stylesheets/foo.css")
  end

  def test_mirror_assets
    Redmine::PluginLoader.mirror_assets

    assert File.exist?("#{@klass.public_directory}/foo_plugin")
    assert File.exist?("#{@klass.public_directory}/foo_plugin/stylesheets/foo.css")
  end

  def test_mirror_assets_with_plugin_name
    Redmine::PluginLoader.mirror_assets('foo_plugin')

    assert File.exist?("#{@klass.public_directory}/foo_plugin")
    assert File.exist?("#{@klass.public_directory}/foo_plugin/stylesheets/foo.css")
  end

  def clear_public
    FileUtils.rm_rf 'tmp/public'
  end
end
