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

class Redmine::PluginTest < ActiveSupport::TestCase
  def setup
    @klass = Redmine::Plugin
    # In case some real plugins are installed
    @klass.clear
  end

  def teardown
    @klass.clear
  end

  def test_register
    @klass.register :foo do
      name 'Foo plugin'
      url 'http://example.net/plugins/foo'
      author 'John Smith'
      author_url 'http://example.net/jsmith'
      description 'This is a test plugin'
      version '0.0.1'
      settings :default => {'sample_setting' => 'value', 'foo'=>'bar'}, :partial => 'foo/settings'
    end

    assert_equal 1, @klass.all.size

    plugin = @klass.find('foo')
    assert plugin.is_a?(Redmine::Plugin)
    assert_equal :foo, plugin.id
    assert_equal 'Foo plugin', plugin.name
    assert_equal 'http://example.net/plugins/foo', plugin.url
    assert_equal 'John Smith', plugin.author
    assert_equal 'http://example.net/jsmith', plugin.author_url
    assert_equal 'This is a test plugin', plugin.description
    assert_equal '0.0.1', plugin.version
  end

  def test_installed
    @klass.register(:foo) {}
    assert_equal true, @klass.installed?(:foo)
    assert_equal false, @klass.installed?(:bar)
  end

  def test_menu
    assert_difference 'Redmine::MenuManager.items(:project_menu).size' do
      @klass.register :foo do
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
      @klass.register :foo do
        delete_menu_item :project_menu, :foo_menu_item
      end
    end
    assert_nil Redmine::MenuManager.items(:project_menu).detect {|i| i.name == :foo_menu_item}
  ensure
    Redmine::MenuManager.map(:project_menu).delete(:foo_menu_item)
  end

  def test_directory_with_override
    @klass.register(:foo) do
      directory '/path/to/foo'
    end
    assert_equal '/path/to/foo', @klass.find('foo').directory
  end

  def test_directory_without_override
    @klass.register(:foo) {}
    assert_equal File.join(@klass.directory, 'foo'), @klass.find('foo').directory
  end

  def test_requires_redmine
    plugin = Redmine::Plugin.register(:foo) {}
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
    @klass.register :other do
      name 'Other'
      version other_version
    end
    @klass.register :foo do
      test.assert requires_redmine_plugin(:other, :version_or_higher => '0.1.0')
      test.assert requires_redmine_plugin(:other, :version_or_higher => other_version)
      test.assert requires_redmine_plugin(:other, other_version)
      test.assert_raise Redmine::PluginRequirementError do
        requires_redmine_plugin(:other, :version_or_higher => '99.0.0')
      end
      test.assert requires_redmine_plugin(:other, :version => other_version)
      test.assert requires_redmine_plugin(:other, :version => [other_version, '99.0.0'])
      test.assert_raise Redmine::PluginRequirementError do
        requires_redmine_plugin(:other, :version => '99.0.0')
      end
      test.assert_raise Redmine::PluginRequirementError do
        requires_redmine_plugin(:other, :version => ['98.0.0', '99.0.0'])
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

  def test_settings_warns_about_possible_partial_collision
    @klass.register(:foo) { settings :partial => 'foo/settings' }
    Rails.logger.expects(:warn)
    @klass.register(:bar) { settings :partial => 'foo/settings' }
  end

  def test_migrate_redmine_plugin
    @klass.register :foo do
      name 'Foo plugin'
      version '0.0.1'
    end

    assert Redmine::Plugin.migrate('foo')
  end
end
