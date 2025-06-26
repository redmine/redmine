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

class Redmine::MenuManager::MenuHelperTest < Redmine::HelperTest
  include Redmine::MenuManager::MenuHelper
  include ERB::Util
  include Rails.application.routes.url_helpers

  fixtures :users, :members, :projects, :enabled_modules, :roles, :member_roles

  def setup
    setup_with_controller
    # Stub the current menu item in the controller
    self.class_eval do
      def current_menu_item
        :index
      end
    end
  end

  def test_render_single_menu_node
    node = Redmine::MenuManager::MenuItem.new(:testing, '/test', {})
    @output_buffer = render_single_menu_node(node, 'This is a test', node.url, false)

    assert_select("a.testing", "This is a test")
  end

  def test_render_menu_node
    single_node = Redmine::MenuManager::MenuItem.new(:single_node, '/test', {})
    @output_buffer = render_menu_node(single_node, nil)

    assert_select("li") do
      assert_select("a.single-node", "Single node")
    end
  end

  def test_render_menu_node_with_symbol_as_url
    node = Redmine::MenuManager::MenuItem.new(:testing, :issues_path)
    @output_buffer = render_menu_node(node, nil)

    assert_select 'a[href="/issues"]', "Testing"
  end

  def test_render_menu_node_with_symbol_as_url_and_project
    node = Redmine::MenuManager::MenuItem.new(:testing, :project_issues_path)
    @output_buffer = render_menu_node(node, Project.find(1))

    assert_select 'a[href="/projects/ecookbook/issues"]', "Testing"
  end

  def test_render_menu_node_with_nested_items
    parent_node = Redmine::MenuManager::MenuItem.new(:parent_node, '/test', {})
    parent_node << Redmine::MenuManager::MenuItem.new(:child_one_node, '/test', {})
    parent_node << Redmine::MenuManager::MenuItem.new(:child_two_node, '/test', {})
    parent_node <<
      Redmine::MenuManager::MenuItem.new(:child_three_node, '/test', {}) <<
      Redmine::MenuManager::MenuItem.new(:child_three_inner_node, '/test', {})

    @output_buffer = render_menu_node(parent_node, nil)

    assert_select("li") do
      assert_select("a.parent-node", "Parent node")
      assert_select("ul") do
        assert_select("li a.child-one-node", "Child one node")
        assert_select("li a.child-two-node", "Child two node")
        assert_select("li") do
          assert_select("a.child-three-node", "Child three node")
          assert_select("ul") do
            assert_select("li a.child-three-inner-node", "Child three inner node")
          end
        end
      end
    end
  end

  def test_render_menu_node_with_children
    User.current = User.find(2)
    parent_node =
      Redmine::MenuManager::MenuItem.
        new(
          :parent_node,
          '/test',
          {
            :children => Proc.new do |p|
              children = []
              3.times do |time|
                children << Redmine::MenuManager::MenuItem.new(
                  "test_child_#{time}",
                  {:controller => 'issues', :action => 'index'},
                  {}
                )
              end
              children
            end
          }
        )
    @output_buffer = render_menu_node(parent_node, Project.find(1))

    assert_select("li") do
      assert_select("a.parent-node", "Parent node")
      assert_select("ul") do
        assert_select("li a.test-child-0", "Test child 0")
        assert_select("li a.test-child-1", "Test child 1")
        assert_select("li a.test-child-2", "Test child 2")
      end
    end
  end

  def test_render_menu_node_with_nested_items_and_children
    User.current = User.find(2)
    parent_node =
      Redmine::MenuManager::MenuItem.new(
        :parent_node,
        {:controller => 'issues', :action => 'index'},
        {
          :children => Proc.new do |p|
            children = []
            3.times do |time|
              children <<
                Redmine::MenuManager::MenuItem.new(
                  "test_child_#{time}",
                  {:controller => 'issues', :action => 'index'}, {}
                )
            end
            children
          end
        }
      )
    parent_node <<
      Redmine::MenuManager::MenuItem.new(
        :child_node,
        {:controller => 'issues', :action => 'index'},
        {
          :children =>
          Proc.new do |p|
            children = []
            6.times do |time|
              children <<
                Redmine::MenuManager::MenuItem.new(
                  "test_dynamic_child_#{time}",
                  {:controller => 'issues', :action => 'index'}, {}
                )
            end
            children
          end
        }
      )
    @output_buffer = render_menu_node(parent_node, Project.find(1))

    assert_select("li") do
      assert_select("a.parent-node", "Parent node")
      assert_select("ul") do
        assert_select("li a.child-node", "Child node")
        assert_select("ul") do
          assert_select("li a.test-dynamic-child-0", "Test dynamic child 0")
          assert_select("li a.test-dynamic-child-1", "Test dynamic child 1")
          assert_select("li a.test-dynamic-child-2", "Test dynamic child 2")
          assert_select("li a.test-dynamic-child-3", "Test dynamic child 3")
          assert_select("li a.test-dynamic-child-4", "Test dynamic child 4")
          assert_select("li a.test-dynamic-child-5", "Test dynamic child 5")
        end
        assert_select("li a.test-child-0", "Test child 0")
        assert_select("li a.test-child-1", "Test child 1")
        assert_select("li a.test-child-2", "Test child 2")
      end
    end
  end

  def test_render_menu_node_with_allowed_and_unallowed_unattached_children
    User.current = User.find(2)
    parent_node =
      Redmine::MenuManager::MenuItem.new(
        :parent_node,
        {:controller => 'issues', :action => 'index'},
        {
          :children => Proc.new do |p|
            [
              Redmine::MenuManager::MenuItem.new(
                "test_child_allowed",
                {:controller => 'issues', :action => 'index'}, {}
              ),
              Redmine::MenuManager::MenuItem.new(
                "test_child_unallowed",
                {:controller => 'issues', :action => 'unallowed'}, {}
              ),
            ]
          end
        }
      )
    @output_buffer = render_menu_node(parent_node, Project.find(1))

    assert_select("li") do
      assert_select("a.parent-node", "Parent node")
      assert_select("ul.menu-children.unattached") do
        assert_select("li a.test-child-allowed", "Test child allowed")
        assert_select("li a.test-child-unallowed", false)
      end
    end
  end

  def test_render_menu_node_with_allowed_and_unallowed_standard_children
    User.current = User.find(6)

    Redmine::MenuManager.map :some_menu do |menu|
      menu.push(:parent_node, {:controller => 'issues', :action => 'index'}, {})
      menu.push(:test_child_allowed, {:controller => 'issues', :action => 'index'}, {:parent => :parent_node})
      menu.push(:test_child_unallowed, {:controller => 'issues', :action => 'new'}, {:parent => :parent_node})
    end

    @output_buffer = render_menu(:some_menu, Project.find(1))

    assert_select("li") do
      assert_select("a.parent-node", "Parent node")
      assert_select("ul.menu-children.unattached", false)
      assert_select("ul.menu-children") do
        assert_select("li a.test-child-allowed", "Test child allowed")
        assert_select("li a.test-child-unallowed", false)
      end
    end
  end

  def test_render_empty_virtual_menu_node_with_children
    # only empty item with no click target
    Redmine::MenuManager.map :menu1 do |menu|
      menu.push(:parent_node, nil, {})
    end

    # parent with unallowed unattached child
    Redmine::MenuManager.map :menu2 do |menu|
      menu.push(
        :parent_node, nil,
        {
          :children =>
            Proc.new do |p|
              [
                Redmine::MenuManager::MenuItem.new(
                  "test_child_unallowed",
                  {:controller => 'issues', :action => 'new'}, {}
                )
              ]
            end
        }
      )
    end

    # parent with unallowed standard child
    Redmine::MenuManager.map :menu3 do |menu|
      menu.push(:parent_node, nil, {})
      menu.push(:test_child_unallowed, {:controller =>'issues', :action => 'new'}, {:parent => :parent_node})
    end

    # should not be displayed to anonymous
    User.current = User.find(6)
    assert_nil render_menu(:menu1, Project.find(1))
    assert_nil render_menu(:menu2, Project.find(1))
    assert_nil render_menu(:menu3, Project.find(1))

    # should be displayed to an admin
    User.current = User.find(1)
    @output_buffer = render_menu(:menu2, Project.find(1))
    assert_select("ul li a.parent-node", "Parent node")
    @output_buffer = render_menu(:menu3, Project.find(1))
    assert_select("ul li a.parent-node", "Parent node")
  end

  def test_render_menu_node_with_children_without_an_array
    parent_node =
      Redmine::MenuManager::MenuItem.new(
        :parent_node,
        '/test',
        {
          :children =>
            Proc.new do |p|
              Redmine::MenuManager::MenuItem.new("test_child", "/testing", {})
            end
        }
      )
    assert_raises Redmine::MenuManager::MenuError, ":children must be an array of MenuItems" do
      @output_buffer = render_menu_node(parent_node, Project.find(1))
    end
  end

  def test_render_menu_node_with_incorrect_children
    parent_node =
      Redmine::MenuManager::MenuItem.new(
        :parent_node,
        '/test',
        {
          :children => Proc.new {|p| ["a string"]}
        }
      )
    assert_raises Redmine::MenuManager::MenuError, ":children must be an array of MenuItems" do
      @output_buffer = render_menu_node(parent_node, Project.find(1))
    end
  end

  def test_menu_items_for_should_yield_all_items_if_passed_a_block
    menu_name = :test_menu_items_for_should_yield_all_items_if_passed_a_block
    Redmine::MenuManager.map menu_name do |menu|
      menu.push(:a_menu, '/', {})
      menu.push(:a_menu_2, '/', {})
      menu.push(:a_menu_3, '/', {})
    end

    items_yielded = []
    menu_items_for(menu_name) do |item|
      items_yielded << item
    end

    assert_equal 3, items_yielded.size
  end

  def test_menu_items_for_should_return_all_items
    menu_name = :test_menu_items_for_should_return_all_items
    Redmine::MenuManager.map menu_name do |menu|
      menu.push(:a_menu, '/', {})
      menu.push(:a_menu_2, '/', {})
      menu.push(:a_menu_3, '/', {})
    end

    items = menu_items_for(menu_name)
    assert_equal 3, items.size
  end

  def test_menu_items_for_should_skip_unallowed_items_on_a_project
    menu_name = :test_menu_items_for_should_skip_unallowed_items_on_a_project
    Redmine::MenuManager.map menu_name do |menu|
      menu.push(:a_menu, {:controller => 'issues', :action => 'index'}, {})
      menu.push(:a_menu_2, {:controller => 'issues', :action => 'index'}, {})
      menu.push(:unallowed, {:controller => 'issues', :action => 'unallowed'}, {})
    end

    User.current = User.find(2)

    items = menu_items_for(menu_name, Project.find(1))
    assert_equal 2, items.size
  end

  def test_menu_items_for_should_skip_items_that_fail_the_permission
    menu_name = :test_menu_items_for_should_skip_items_that_fail_the_permission
    Redmine::MenuManager.map menu_name do |menu|
      menu.push(:a_menu, :project_issues_path)
      menu.push(:unallowed, :project_issues_path, :permission => :unallowed)
    end

    User.current = User.find(2)

    items = menu_items_for(menu_name, Project.find(1))
    assert_equal 1, items.size
  end

  def test_menu_items_for_should_skip_items_that_fail_the_conditions
    menu_name = :test_menu_items_for_should_skip_items_that_fail_the_conditions
    Redmine::MenuManager.map menu_name do |menu|
      menu.push(:a_menu, {:controller => 'issues', :action => 'index'}, {})
      menu.push(:unallowed,
                {:controller => 'issues', :action => 'index'},
                {:if => Proc.new {false}})
    end

    User.current = User.find(2)

    items = menu_items_for(menu_name, Project.find(1))
    assert_equal 1, items.size
  end
end
