# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

require File.expand_path('../../test_helper', __FILE__)

class DocumentCategoryTest < ActiveSupport::TestCase
  fixtures :enumerations, :documents, :issues

  def test_should_be_an_enumeration
    assert DocumentCategory.ancestors.include?(Enumeration)
  end

  def test_objects_count
    assert_equal 2, DocumentCategory.find_by_name("Uncategorized").objects_count
    assert_equal 0, DocumentCategory.find_by_name("User documentation").objects_count
  end

  def test_option_name
    assert_equal :enumeration_doc_categories, DocumentCategory.new.option_name
  end

  def test_default
    assert_nil DocumentCategory.where(:is_default => true).first
    e = Enumeration.find_by_name('Technical documentation')
    e.update_attributes(:is_default => true)
    assert_equal 3, DocumentCategory.default.id
  end

  def test_force_default
    assert_nil DocumentCategory.where(:is_default => true).first
    assert_equal 1, DocumentCategory.default.id
  end
end
