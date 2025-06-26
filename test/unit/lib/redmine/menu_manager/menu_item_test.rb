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

require File.expand_path('../../../../../test_helper', __FILE__)

module RedmineMenuTestHelper
  # Helpers
  def get_menu_item(menu_name, item_name)
    Redmine::MenuManager.items(menu_name).find {|item| item.name == item_name.to_sym}
  end
end

class Redmine::MenuManager::MenuItemTest < ActiveSupport::TestCase
  include RedmineMenuTestHelper

  Redmine::MenuManager.map :test_menu do |menu|
    menu.push(:parent, '/test', {})
    menu.push(:child_menu, '/test', {:parent => :parent})
    menu.push(:child2_menu, '/test', {:parent => :parent})
  end

  # context new menu item
  def test_new_menu_item_should_require_a_name
    assert_raises ArgumentError do
      Redmine::MenuManager::MenuItem.new
    end
  end

  def test_new_menu_item_should_require_an_url
    assert_raises ArgumentError do
      Redmine::MenuManager::MenuItem.new(:test_missing_url)
    end
  end

  def test_new_menu_item_with_all_required_parameters
    assert Redmine::MenuManager::MenuItem.new(:test_good_menu, '/test', {})
  end

  def test_new_menu_item_should_require_a_proc_to_use_for_the_if_condition
    assert_raises ArgumentError do
      Redmine::MenuManager::MenuItem.new(
        :test_error, '/test', {:if => ['not_a_proc']}
      )
    end

    assert(
      Redmine::MenuManager::MenuItem.new(
        :test_good_if, '/test', {:if => Proc.new{}}
      )
    )
  end

  def test_new_menu_item_should_allow_a_hash_for_extra_html_options
    assert_raises ArgumentError do
      Redmine::MenuManager::MenuItem.new(
        :test_error, '/test',
        {:html => ['not_a_hash']}
      )
    end
    assert(
      Redmine::MenuManager::MenuItem.new(
        :test_good_html, '/test',
        {:html => {:onclick => 'doSomething'}}
      )
    )
  end

  def test_new_menu_item_should_require_a_proc_to_use_the_children_option
    assert_raises ArgumentError do
      Redmine::MenuManager::MenuItem.new(
        :test_error, '/test', {:children => ['not_a_proc']}
      )
    end
    assert(
      Redmine::MenuManager::MenuItem.new(
        :test_good_children, '/test', {:children => Proc.new{}}
      )
    )
  end

  def test_new_should_not_allow_setting_the_parent_item_to_the_current_item
    assert_raises ArgumentError do
      Redmine::MenuManager::MenuItem.new(
        :test_error, '/test', {:parent => :test_error}
      )
    end
  end

  def test_has_children
    parent_item = get_menu_item(:test_menu, :parent)
    assert parent_item.children.present?
    assert_equal 2, parent_item.children.size
    assert_equal get_menu_item(:test_menu, :child_menu), parent_item.children[0]
    assert_equal get_menu_item(:test_menu, :child2_menu), parent_item.children[1]
  end
end
