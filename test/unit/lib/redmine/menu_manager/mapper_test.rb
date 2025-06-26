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

class Redmine::MenuManager::MapperTest < ActiveSupport::TestCase
  test "Mapper#initialize should define a root MenuNode if menu is not present in items" do
    menu_mapper = Redmine::MenuManager::Mapper.new(:test_menu, {})
    node = menu_mapper.menu_items
    assert_not_nil node
    assert_equal :root, node.name
  end

  test "Mapper#initialize should use existing MenuNode if present" do
    node = "foo" # just an arbitrary reference
    menu_mapper = Redmine::MenuManager::Mapper.new(:test_menu, {:test_menu => node})
    assert_equal node, menu_mapper.menu_items
  end

  def test_push_onto_root
    menu_mapper = Redmine::MenuManager::Mapper.new(:test_menu, {})
    menu_mapper.push :test_overview, {:controller => 'projects', :action => 'show'}, {}

    menu_mapper.exists?(:test_overview)
  end

  def test_push_onto_parent
    menu_mapper = Redmine::MenuManager::Mapper.new(:test_menu, {})
    menu_mapper.push :test_overview, {:controller => 'projects', :action => 'show'}, {}
    menu_mapper.push :test_child, {:controller => 'projects', :action => 'show'}, {:parent => :test_overview}

    assert menu_mapper.exists?(:test_child)
    assert_equal :test_child, menu_mapper.find(:test_child).name
  end

  def test_push_onto_grandparent
    menu_mapper = Redmine::MenuManager::Mapper.new(:test_menu, {})
    menu_mapper.push :test_overview, {:controller => 'projects', :action => 'show'}, {}
    menu_mapper.push :test_child, {:controller => 'projects', :action => 'show'}, {:parent => :test_overview}
    menu_mapper.push :test_grandchild, {:controller => 'projects', :action => 'show'}, {:parent => :test_child}

    assert menu_mapper.exists?(:test_grandchild)
    grandchild = menu_mapper.find(:test_grandchild)
    assert_equal :test_grandchild, grandchild.name
    assert_equal :test_child, grandchild.parent.name
  end

  def test_push_first
    menu_mapper = Redmine::MenuManager::Mapper.new(:test_menu, {})
    menu_mapper.push :test_second, {:controller => 'projects', :action => 'show'}, {}
    menu_mapper.push :test_third, {:controller => 'projects', :action => 'show'}, {}
    menu_mapper.push :test_fourth, {:controller => 'projects', :action => 'show'}, {}
    menu_mapper.push :test_fifth, {:controller => 'projects', :action => 'show'}, {}
    menu_mapper.push :test_first,
                     {:controller => 'projects', :action => 'show'},
                     {:first => true}
    root = menu_mapper.find(:root)
    assert_equal 5, root.children.size
    {0 => :test_first, 1 => :test_second, 2 => :test_third,
     3 => :test_fourth, 4 => :test_fifth}.each do |position, name|
      assert_not_nil root.children[position]
      assert_equal name, root.children[position].name
    end
  end

  def test_push_before
    menu_mapper = Redmine::MenuManager::Mapper.new(:test_menu, {})
    menu_mapper.push :test_first, {:controller => 'projects', :action => 'show'}, {}
    menu_mapper.push :test_second, {:controller => 'projects', :action => 'show'}, {}
    menu_mapper.push :test_fourth, {:controller => 'projects', :action => 'show'}, {}
    menu_mapper.push :test_fifth, {:controller => 'projects', :action => 'show'}, {}
    menu_mapper.push :test_third,
                     {:controller => 'projects', :action => 'show'},
                     {:before => :test_fourth}
    root = menu_mapper.find(:root)
    assert_equal 5, root.children.size
    {0 => :test_first, 1 => :test_second, 2 => :test_third, 3 => :test_fourth,
     4 => :test_fifth}.each do |position, name|
      assert_not_nil root.children[position]
      assert_equal name, root.children[position].name
    end
  end

  def test_push_after
    menu_mapper = Redmine::MenuManager::Mapper.new(:test_menu, {})
    menu_mapper.push :test_first, {:controller => 'projects', :action => 'show'}, {}
    menu_mapper.push :test_second, {:controller => 'projects', :action => 'show'}, {}
    menu_mapper.push :test_third, {:controller => 'projects', :action => 'show'}, {}
    menu_mapper.push :test_fifth, {:controller => 'projects', :action => 'show'}, {}
    menu_mapper.push :test_fourth,
                     {:controller => 'projects', :action => 'show'},
                     {:after => :test_third}
    root = menu_mapper.find(:root)
    assert_equal 5, root.children.size
    {0 => :test_first, 1 => :test_second, 2 => :test_third,
     3 => :test_fourth, 4 => :test_fifth}.each do |position, name|
      assert_not_nil root.children[position]
      assert_equal name, root.children[position].name
    end
  end

  def test_push_last
    menu_mapper = Redmine::MenuManager::Mapper.new(:test_menu, {})
    menu_mapper.push :test_first, {:controller => 'projects', :action => 'show'}, {}
    menu_mapper.push :test_second, {:controller => 'projects', :action => 'show'}, {}
    menu_mapper.push :test_third, {:controller => 'projects', :action => 'show'}, {}
    menu_mapper.push :test_fifth, {:controller => 'projects', :action => 'show'}, {:last => true}
    menu_mapper.push :test_fourth, {:controller => 'projects', :action => 'show'}, {}
    root = menu_mapper.find(:root)
    assert_equal 5, root.children.size
    {0 => :test_first, 1 => :test_second, 2 => :test_third,
     3 => :test_fourth, 4 => :test_fifth}.each do |position, name|
      assert_not_nil root.children[position]
      assert_equal name, root.children[position].name
    end
  end

  def test_exists_for_child_node
    menu_mapper = Redmine::MenuManager::Mapper.new(:test_menu, {})
    menu_mapper.push :test_overview, {:controller => 'projects', :action => 'show'}, {}
    menu_mapper.push :test_child,
                     {:controller => 'projects', :action => 'show'},
                     {:parent => :test_overview}
    assert menu_mapper.exists?(:test_child)
  end

  def test_exists_for_invalid_node
    menu_mapper = Redmine::MenuManager::Mapper.new(:test_menu, {})
    menu_mapper.push :test_overview, {:controller => 'projects', :action => 'show'}, {}

    assert !menu_mapper.exists?(:nothing)
  end

  def test_find
    menu_mapper = Redmine::MenuManager::Mapper.new(:test_menu, {})
    menu_mapper.push :test_overview, {:controller => 'projects', :action => 'show'}, {}

    item = menu_mapper.find(:test_overview)
    assert_equal :test_overview, item.name
    assert_equal({:controller => 'projects', :action => 'show'}, item.url)
  end

  def test_find_missing
    menu_mapper = Redmine::MenuManager::Mapper.new(:test_menu, {})
    menu_mapper.push :test_overview, {:controller => 'projects', :action => 'show'}, {}

    item = menu_mapper.find(:nothing)
    assert_nil item
  end

  def test_delete
    menu_mapper = Redmine::MenuManager::Mapper.new(:test_menu, {})
    menu_mapper.push :test_overview, {:controller => 'projects', :action => 'show'}, {}
    assert_not_nil menu_mapper.delete(:test_overview)

    assert_nil menu_mapper.find(:test_overview)
  end

  def test_delete_missing
    menu_mapper = Redmine::MenuManager::Mapper.new(:test_menu, {})
    assert_nil menu_mapper.delete(:test_missing)
  end

  test 'deleting all items' do
    # Exposed by deleting :last items
    Redmine::MenuManager.map :test_menu do |menu|
      menu.push :not_last, Redmine::Info.help_url
      menu.push :administration, {:controller => 'projects', :action => 'show'}, {:last => true}
      menu.push :help, Redmine::Info.help_url, :last => true
    end
    assert_nothing_raised do
      Redmine::MenuManager.map :test_menu do |menu|
        menu.delete(:administration)
        menu.delete(:help)
        menu.push :test_overview, {:controller => 'projects', :action => 'show'}, {}
      end
    end
  end
end
