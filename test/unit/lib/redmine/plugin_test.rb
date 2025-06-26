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

require File.expand_path('../../../../test_helper', __FILE__)

class Redmine::PluginTest < ActiveSupport::TestCase
  def setup
    @klass = Redmine::Plugin
    # Change plugin directory for testing to default
    # plugins/foo => test/fixtures/plugins/foo
    @klass.directory = Rails.root.join('test/fixtures/plugins')
    # In case some real plugins are installed
    @klass.clear

    # Change plugin loader's directory for testing
    Redmine::PluginLoader.directory = @klass.directory
    Redmine::PluginLoader.setup
  end

  def teardown
    @klass.clear
  end

  def test_register
    @klass.register :foo_plugin do
      name 'Foo plugin'
      url 'http://example.net/plugins/foo'
      author 'John Smith'
      author_url 'http://example.net/jsmith'
      description 'This is a test plugin'
      version '0.0.1'
      settings :default => {'sample_setting' => 'value', 'foo'=>'bar'}, :partial => 'foo/settings'
    end

    assert_equal 1, @klass.all.size

    plugin = @klass.find('foo_plugin')
    assert plugin.is_a?(Redmine::Plugin)
    assert_equal :foo_plugin, plugin.id
    assert_equal 'Foo plugin', plugin.name
    assert_equal 'http://example.net/plugins/foo', plugin.url
    assert_equal 'John Smith', plugin.author
    assert_equal 'http://example.net/jsmith', plugin.author_url
    assert_equal 'This is a test plugin', plugin.description
    assert_equal '0.0.1', plugin.version
    assert_equal File.join(@klass.directory, 'foo_plugin', 'assets'), plugin.assets_directory
  end

  ::FooModel = Class.new(ActiveRecord::Base)
  def test_register_attachment_object_type
    Redmine::Acts::Attachable::ObjectTypeConstraint.expects(:register_object_type).with("foo_models")
    @klass.register :foo_plugin do
      attachment_object_type FooModel
    end
  end

  def test_register_should_raise_error_if_plugin_directory_does_not_exist
    e = assert_raises Redmine::PluginNotFound do
      @klass.register(:bar_plugin) {}
    end

    assert_equal "Plugin not found. The directory for plugin bar_plugin should be #{Rails.root.join('test/fixtures/plugins/bar_plugin')}.", e.message
  end

  def test_installed
    @klass.register(:foo_plugin) {}
    assert_equal true, @klass.installed?(:foo_plugin)
    assert_equal false, @klass.installed?(:bar)
  end

  def test_menu
    assert_difference 'Redmine::MenuManager.items(:project_menu).size' do
      @klass.register :foo_plugin do
        menu :project_menu, :foo_menu_item, '/foo', :caption => 'Foo'
      end
    end
    menu_item = Redmine::MenuManager.items(:project_menu).detect {|i| i.name == :foo_menu_item}
    assert_not_nil menu_item
    assert_equal 'Foo', menu_item.caption
    assert_equal '/foo', menu_item.url
  ensure
    Redmine::MenuManager.map(:project_menu).delete(:foo_menu_item)
  end

  def test_delete_menu_item
    Redmine::MenuManager.map(:project_menu).push(:foo_menu_item, '/foo', :caption => 'Foo')
    assert_difference 'Redmine::MenuManager.items(:project_menu).size', -1 do
      @klass.register :foo_plugin do
        delete_menu_item :project_menu, :foo_menu_item
      end
    end
    assert_nil Redmine::MenuManager.items(:project_menu).detect {|i| i.name == :foo_menu_item}
  ensure
    Redmine::MenuManager.map(:project_menu).delete(:foo_menu_item)
  end

  def test_directory_with_override
    @klass.register(:foo) do
      directory 'test/fixtures/plugins/foo_plugin'
    end
    assert_equal 'test/fixtures/plugins/foo_plugin', @klass.find('foo').directory
  end

  def test_directory_without_override
    @klass.register(:other_plugin) {}
    assert_equal File.join(@klass.directory, 'other_plugin'), @klass.find('other_plugin').directory
  end

  def test_requires_redmine
    plugin = Redmine::Plugin.register(:foo_plugin) {}
    Redmine::VERSION.stubs(:to_a).returns([2, 1, 3, "stable", 10817])
    # Specific version without hash
    assert plugin.requires_redmine('2.1.3')
    assert plugin.requires_redmine('2.1')
    assert_raise Redmine::PluginRequirementError do
      plugin.requires_redmine('2.1.4')
    end
    assert_raise Redmine::PluginRequirementError do
      plugin.requires_redmine('2.2')
    end
    # Specific version
    assert plugin.requires_redmine(:version => '2.1.3')
    assert plugin.requires_redmine(:version => ['2.1.3', '2.2.0'])
    assert plugin.requires_redmine(:version => '2.1')
    assert_raise Redmine::PluginRequirementError do
      plugin.requires_redmine(:version => '2.2.0')
    end
    assert_raise Redmine::PluginRequirementError do
      plugin.requires_redmine(:version => ['2.1.4', '2.2.0'])
    end
    assert_raise Redmine::PluginRequirementError do
      plugin.requires_redmine(:version => '2.2')
    end
    # Version range
    assert plugin.requires_redmine(:version => '2.0.0'..'2.2.4')
    assert plugin.requires_redmine(:version => '2.1.3'..'2.2.4')
    assert plugin.requires_redmine(:version => '2.0.0'..'2.1.3')
    assert plugin.requires_redmine(:version => '2.0'..'2.2')
    assert plugin.requires_redmine(:version => '2.1'..'2.2')
    assert plugin.requires_redmine(:version => '2.0'..'2.1')
    assert_raise Redmine::PluginRequirementError do
      plugin.requires_redmine(:version => '2.1.4'..'2.2.4')
    end
    # Version or higher
    assert plugin.requires_redmine(:version_or_higher => '0.1.0')
    assert plugin.requires_redmine(:version_or_higher => '2.1.3')
    assert plugin.requires_redmine(:version_or_higher => '2.1')
    assert_raise Redmine::PluginRequirementError do
      plugin.requires_redmine(:version_or_higher => '2.2.0')
    end
    assert_raise Redmine::PluginRequirementError do
      plugin.requires_redmine(:version_or_higher => '2.2')
    end
  end

  def test_requires_redmine_plugin
    test = self
    other_version = '0.5.0'
    @klass.register :other_plugin do
      name 'Other'
      version other_version
    end
    @klass.register :foo_plugin do
      test.assert requires_redmine_plugin(:other_plugin, :version_or_higher => '0.1.0')
      test.assert requires_redmine_plugin(:other_plugin, :version_or_higher => other_version)
      test.assert requires_redmine_plugin(:other_plugin, other_version)
      test.assert_raise Redmine::PluginRequirementError do
        requires_redmine_plugin(:other_plugin, :version_or_higher => '99.0.0')
      end
      test.assert requires_redmine_plugin(:other_plugin, :version => other_version)
      test.assert requires_redmine_plugin(:other_plugin, :version => [other_version, '99.0.0'])
      test.assert_raise Redmine::PluginRequirementError do
        requires_redmine_plugin(:other_plugin, :version => '99.0.0')
      end
      test.assert_raise Redmine::PluginRequirementError do
        requires_redmine_plugin(:other_plugin, :version => ['98.0.0', '99.0.0'])
      end
      # Missing plugin
      test.assert_raise Redmine::PluginRequirementError do
        requires_redmine_plugin(:missing, :version_or_higher => '0.1.0')
      end
      test.assert_raise Redmine::PluginRequirementError do
        requires_redmine_plugin(:missing, '0.1.0')
      end
      test.assert_raise Redmine::PluginRequirementError do
        requires_redmine_plugin(:missing, :version => '0.1.0')
      end
    end
  end

  def test_default_settings
    @klass.register(:foo_plugin) {settings :default => {'key1' => 'abc', :key2 => 123}}
    h = Setting.plugin_foo_plugin
    assert_equal 'abc', h['key1']
    assert_equal 123, h[:key2]
  end

  def test_settings_warns_about_possible_partial_collision
    @klass.register(:foo_plugin) {settings :partial => 'foo/settings'}
    Rails.logger.expects(:warn)
    @klass.register(:other_plugin) {settings :partial => 'foo/settings'}
  end

  def test_migrate_redmine_plugin
    @klass.register :foo_plugin do
      name 'Foo plugin'
      version '0.0.1'
    end

    assert Redmine::Plugin.migrate('foo_plugin')
  end
end
