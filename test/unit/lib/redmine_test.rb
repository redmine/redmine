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

require_relative '../../test_helper'

module RedmineMenuTestHelper
  # Assertions
  def assert_number_of_items_in_menu(menu_name, count)
    assert Redmine::MenuManager.items(menu_name).size >= count, "Menu has less than #{count} items"
  end

  def assert_menu_contains_item_named(menu_name, item_name)
    assert Redmine::MenuManager.items(menu_name).collect(&:name).include?(item_name.to_sym), "Menu did not have an item named #{item_name}"
  end

  # Helpers
  def get_menu_item(menu_name, item_name)
    Redmine::MenuManager.items(menu_name).find {|item| item.name == item_name.to_sym}
  end
end

class RedmineTest < ActiveSupport::TestCase
  include RedmineMenuTestHelper

  def test_top_menu
    assert_number_of_items_in_menu :top_menu, 5
    assert_menu_contains_item_named :top_menu, :home
    assert_menu_contains_item_named :top_menu, :my_page
    assert_menu_contains_item_named :top_menu, :projects
    assert_menu_contains_item_named :top_menu, :administration
    assert_menu_contains_item_named :top_menu, :help
  end

  def test_account_menu
    assert_number_of_items_in_menu :account_menu, 4
    assert_menu_contains_item_named :account_menu, :login
    assert_menu_contains_item_named :account_menu, :register
    assert_menu_contains_item_named :account_menu, :my_account
    assert_menu_contains_item_named :account_menu, :logout
  end

  def test_application_menu
    assert_number_of_items_in_menu :application_menu, 0
  end

  def test_admin_menu
    assert_number_of_items_in_menu :admin_menu, 0
  end

  def test_project_menu
    assert_number_of_items_in_menu :project_menu, 13
    assert_menu_contains_item_named :project_menu, :overview
    assert_menu_contains_item_named :project_menu, :activity
    assert_menu_contains_item_named :project_menu, :roadmap
    assert_menu_contains_item_named :project_menu, :issues
    assert_menu_contains_item_named :project_menu, :calendar
    assert_menu_contains_item_named :project_menu, :gantt
    assert_menu_contains_item_named :project_menu, :news
    assert_menu_contains_item_named :project_menu, :documents
    assert_menu_contains_item_named :project_menu, :wiki
    assert_menu_contains_item_named :project_menu, :boards
    assert_menu_contains_item_named :project_menu, :files
    assert_menu_contains_item_named :project_menu, :repository
    assert_menu_contains_item_named :project_menu, :settings
  end
end
