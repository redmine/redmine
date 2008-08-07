# redMine - project management software
# Copyright (C) 2006-2008  Jean-Philippe Lang
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

require File.dirname(__FILE__) + '/../../../test_helper'

class Redmine::Hook::ManagerTest < Test::Unit::TestCase

  # Some fake hooks that are manually registered in these tests
  class FakeHook
    include Singleton
  end
  
  class TestHook1 < FakeHook
    def view_layouts_base_html_head(context)
      'Test hook 1 listener.'
    end
  end

  class TestHook2 < FakeHook
    def view_layouts_base_html_head(context)
      'Test hook 2 listener.'
    end
  end
  
  class TestHook3 < FakeHook
    def view_layouts_base_html_head(context)
      "Context keys: #{context.keys.collect(&:to_s).sort.join(', ')}."
    end
  end
  
  def setup
    @hook_module = Redmine::Hook
  end
  
  def teardown
    @hook_module.clear_listeners
  end
  
  def test_sanity
    assert true
  end
  
  def test_hooks_format
    assert_kind_of Array, @hook_module.hooks
    @hook_module.hooks.each do |hook|
      assert_kind_of Symbol, hook
      assert_kind_of Array, @hook_module.hook_listeners(hook)
      assert_equal 0, @hook_module.hook_listeners(hook).length
    end
  end
  
  def test_valid_hook
    assert @hook_module.valid_hook?(:view_layouts_base_html_head)
  end
  
  def test_invalid_hook
    assert !@hook_module.valid_hook?(:an_invalid_hook_name)
  end
  
  def test_clear_listeners
    assert_equal 0, @hook_module.hook_listeners(:view_layouts_base_html_head).size
    @hook_module.add_listener(TestHook1)
    @hook_module.add_listener(TestHook2)
    assert_equal 2, @hook_module.hook_listeners(:view_layouts_base_html_head).size
    
    @hook_module.clear_listeners
    assert_equal 0, @hook_module.hook_listeners(:view_layouts_base_html_head).size
  end
  
  def test_add_listener
    assert_equal 0, @hook_module.hook_listeners(:view_layouts_base_html_head).size
    @hook_module.add_listener(TestHook1)
    assert_equal 1, @hook_module.hook_listeners(:view_layouts_base_html_head).size
  end
  
  def test_call_hook
    @hook_module.add_listener(TestHook1)
    assert_equal 'Test hook 1 listener.', @hook_module.call_hook(:view_layouts_base_html_head)
  end
  
  def test_call_hook_with_context
    @hook_module.add_listener(TestHook3)
    assert_equal 'Context keys: bar, foo.', @hook_module.call_hook(:view_layouts_base_html_head, :foo => 1, :bar => 'a')
  end
  
  def test_call_hook_with_multiple_listeners
    @hook_module.add_listener(TestHook1)
    @hook_module.add_listener(TestHook2)
    assert_equal 'Test hook 1 listener.Test hook 2 listener.', @hook_module.call_hook(:view_layouts_base_html_head)
  end
end
