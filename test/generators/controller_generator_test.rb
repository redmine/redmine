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

require_relative '../test_helper'
require_relative '../../lib/generators/redmine_plugin_controller/redmine_plugin_controller_generator'

class ControllerGeneratorTest < Rails::Generators::TestCase
  TMP_DIR = Rails.root / 'tmp/test/generators'

  tests RedminePluginControllerGenerator
  destination TMP_DIR
  setup :prepare_destination

  setup do
    @plugin_directory = Redmine::Plugin.directory
    Redmine::Plugin.directory = TMP_DIR
  end

  teardown do
    Redmine::Plugin.directory = @plugin_directory
  end

  def test_generates_files_from_templates
    g = generator ['ControllerDemo', 'Todo']

    assert_name g, 'Todo', :controller

    capture(:stdout) do
      g.copy_templates
    end

    controller_path_names = (Redmine::Plugin.directory / 'controller_demo/app/controllers')
      .glob('*.rb')
    assert_equal 1, controller_path_names.count
    assert_equal 'todo_controller.rb', controller_path_names.first.basename.to_s

    helper_path_names = (Redmine::Plugin.directory / 'controller_demo/app/helpers')
      .glob('*.rb')
    assert_equal 1, helper_path_names.count
    assert_equal 'todo_helper.rb', helper_path_names.first.basename.to_s

    test_path_names = (Redmine::Plugin.directory / 'controller_demo/test/functional')
      .glob('*.rb')
    assert_equal 1, test_path_names.count
    assert_equal 'todo_controller_test.rb', test_path_names.first.basename.to_s
  end

  private

  def assert_name(generator, value, method)
    assert_equal value, generator.send(method)
  end
end
