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

class SortHelperTest < Redmine::HelperTest
  include SortHelper
  include ERB::Util

  def setup
    super
    @session = nil
    @sort_param = nil
  end

  def test_default_sort_clause_with_array
    sort_init 'attr1', 'desc'
    sort_update(['attr1', 'attr2'])

    assert_equal ['attr1 DESC'], sort_clause
  end

  def test_default_sort_clause_with_hash
    sort_init 'attr1', 'desc'
    sort_update({'attr1' => 'table1.attr1', 'attr2' => 'table2.attr2'})

    assert_equal ['table1.attr1 DESC'], sort_clause
  end

  def test_default_sort_clause_with_multiple_columns
    sort_init 'attr1', 'desc'
    sort_update({'attr1' => ['table1.attr1', 'table1.attr2'], 'attr2' => 'table2.attr2'})

    assert_equal ['table1.attr1 DESC', 'table1.attr2 DESC'], sort_clause
  end

  def test_params_sort
    @sort_param = 'attr1,attr2:desc'

    sort_init 'attr1', 'desc'
    sort_update({'attr1' => 'table1.attr1', 'attr2' => 'table2.attr2'})

    assert_equal ['table1.attr1 ASC', 'table2.attr2 DESC'], sort_clause
    assert_equal 'attr1,attr2:desc', @session['foo_bar_sort']
  end

  def test_invalid_params_sort
    @sort_param = 'invalid_key'

    sort_init 'attr1', 'desc'
    sort_update({'attr1' => 'table1.attr1', 'attr2' => 'table2.attr2'})

    assert_nil sort_clause
    assert_equal 'invalid_key', @session['foo_bar_sort']
  end

  def test_invalid_order_params_sort
    @sort_param = 'attr1:foo:bar,attr2'

    sort_init 'attr1', 'desc'
    sort_update({'attr1' => 'table1.attr1', 'attr2' => 'table2.attr2'})

    assert_equal ['table1.attr1 ASC', 'table2.attr2 ASC'], sort_clause
    assert_equal 'attr1,attr2', @session['foo_bar_sort']
  end

  def test_sort_css_without_params_should_use_default_sort
    sort_init 'attr1', 'desc'
    sort_update(['attr1', 'attr2'])

    assert_equal 'sort-by-attr1 sort-desc', sort_css_classes
  end

  def test_sort_css_should_use_params
    @sort_param = 'attr2,attr1'
    sort_init 'attr1', 'desc'
    sort_update(['attr1', 'attr2'])

    assert_equal 'sort-by-attr2 sort-asc', sort_css_classes
  end

  def test_sort_css_should_dasherize_sort_name
    sort_init 'foo_bar'
    sort_update(['foo_bar'])

    assert_equal 'sort-by-foo-bar sort-asc', sort_css_classes
  end

  private

  def controller_name; 'foo'; end
  def action_name; 'bar'; end
  def params; {:sort => @sort_param}; end
  def session; @session ||= {}; end
end
