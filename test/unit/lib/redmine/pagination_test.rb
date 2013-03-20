# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

class Redmine::PaginationTest < ActiveSupport::TestCase

  def setup
    @klass = Redmine::Pagination::Paginator
  end

  def test_count_is_zero
    p = @klass.new 0, 10, 1

    assert_equal 0, p.offset
    assert_equal 10, p.per_page
    %w(first_page previous_page next_page last_page).each do |method|
      assert_nil p.send(method), "#{method} was not nil"
    end
    assert_equal 0, p.first_item
    assert_equal 0, p.last_item
    assert_equal [], p.linked_pages
  end

  def test_count_is_less_than_per_page
    p = @klass.new 7, 10, 1

    assert_equal 0, p.offset
    assert_equal 10, p.per_page
    assert_equal 1, p.first_page
    assert_nil p.previous_page
    assert_nil p.next_page
    assert_equal 1, p.last_page
    assert_equal 1, p.first_item
    assert_equal 7, p.last_item
    assert_equal [], p.linked_pages
  end

  def test_count_is_equal_to_per_page
    p = @klass.new 10, 10, 1

    assert_equal 0, p.offset
    assert_equal 10, p.per_page
    assert_equal 1, p.first_page
    assert_nil p.previous_page
    assert_nil p.next_page
    assert_equal 1, p.last_page
    assert_equal 1, p.first_item
    assert_equal 10, p.last_item
    assert_equal [], p.linked_pages
  end

  def test_2_pages
    p = @klass.new 16, 10, 1

    assert_equal 0, p.offset
    assert_equal 10, p.per_page
    assert_equal 1, p.first_page
    assert_nil p.previous_page
    assert_equal 2, p.next_page
    assert_equal 2, p.last_page
    assert_equal 1, p.first_item
    assert_equal 10, p.last_item
    assert_equal [1, 2], p.linked_pages
  end

  def test_many_pages
    p = @klass.new 155, 10, 1

    assert_equal 0, p.offset
    assert_equal 10, p.per_page
    assert_equal 1, p.first_page
    assert_nil p.previous_page
    assert_equal 2, p.next_page
    assert_equal 16, p.last_page
    assert_equal 1, p.first_item
    assert_equal 10, p.last_item
    assert_equal [1, 2, 3, 16], p.linked_pages
  end
end
