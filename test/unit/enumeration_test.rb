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

class EnumerationTest < ActiveSupport::TestCase
  def setup
    User.current = nil
  end

  def test_objects_count
    # low priority
    assert_equal 6, Enumeration.find(4).objects_count
    # urgent
    assert_equal 0, Enumeration.find(7).objects_count
  end

  def test_in_use
    # low priority
    assert Enumeration.find(4).in_use?
    # urgent
    assert !Enumeration.find(7).in_use?
  end

  def test_default
    e = Enumeration.default
    assert e.is_a?(Enumeration)
    assert e.is_default?
    assert e.active?
    assert_equal 'Default Enumeration', e.name
  end

  def test_default_non_active
    e = Enumeration.find(12)
    assert e.is_a?(Enumeration)
    assert e.is_default?
    assert e.active?
    e.update(:active => false)
    assert e.is_default?
    assert !e.active?
  end

  def test_create
    e = Enumeration.new(:name => 'Not default', :is_default => false)
    e.type = 'Enumeration'
    assert e.save
    assert_equal 'Default Enumeration', Enumeration.default.name
  end

  def test_create_as_default
    e = Enumeration.new(:name => 'Very urgent', :is_default => true)
    e.type = 'Enumeration'
    assert e.save
    assert_equal e, Enumeration.default
  end

  def test_update_default
    e = Enumeration.default
    e.update(:name => 'Changed', :is_default => true)
    assert_equal e, Enumeration.default
  end

  def test_update_default_to_non_default
    e = Enumeration.default
    e.update(:name => 'Changed', :is_default => false)
    assert_nil Enumeration.default
  end

  def test_change_default
    e = Enumeration.find_by_name('Default Enumeration')
    e.update(:name => 'Changed Enumeration', :is_default => true)
    assert_equal e, Enumeration.default
  end

  def test_destroy_with_reassign
    Enumeration.find(4).destroy(Enumeration.find(6))
    assert_not Issue.where(:priority_id => 4).exists?
    assert_equal 6, Enumeration.find(6).objects_count
  end

  def test_should_be_customizable
    assert Enumeration.included_modules.include?(Redmine::Acts::Customizable::InstanceMethods)
  end

  def test_should_belong_to_a_project
    association = Enumeration.reflect_on_association(:project)
    assert association, "No Project association found"
    assert_equal :belongs_to, association.macro
  end

  def test_should_act_as_tree
    enumeration = Enumeration.find(4)

    assert enumeration.respond_to?(:parent)
    assert enumeration.respond_to?(:children)
  end

  def test_is_override
    # Defaults to off
    enumeration = Enumeration.find(4)
    assert !enumeration.is_override?

    # Setup as an override
    enumeration.parent = Enumeration.find(5)
    assert enumeration.is_override?
  end

  def test_get_subclasses
    classes = Enumeration.get_subclasses
    assert_include IssuePriority, classes
    assert_include DocumentCategory, classes
    assert_include TimeEntryActivity, classes

    classes.each do |klass|
      assert_equal Enumeration, klass.superclass
    end
  end

  def test_list_should_be_scoped_for_each_type
    Enumeration.delete_all

    a = IssuePriority.create!(:name => 'A')
    b = IssuePriority.create!(:name => 'B')
    c = DocumentCategory.create!(:name => 'C')

    assert_equal [1, 2, 1], [a, b, c].map {|e| e.reload.position}
  end

  def test_override_should_be_created_with_same_position_as_parent
    Enumeration.delete_all

    a = IssuePriority.create!(:name => 'A')
    b = IssuePriority.create!(:name => 'B')
    override = IssuePriority.create!(:name => 'BB', :parent_id => b.id)

    assert_equal [1, 2, 2], [a, b, override].map {|e| e.reload.position}
  end

  def test_override_position_should_be_updated_with_parent_position
    Enumeration.delete_all

    a = IssuePriority.create!(:name => 'A')
    b = IssuePriority.create!(:name => 'B')
    override = IssuePriority.create!(:name => 'BB', :parent_id => b.id)
    b.position -= 1
    b.save!

    assert_equal [2, 1, 1], [a, b, override].map {|e| e.reload.position}
  end

  def test_destroying_override_should_not_update_positions
    Enumeration.delete_all
    Issue.delete_all

    a = IssuePriority.create!(:name => 'A')
    b = IssuePriority.create!(:name => 'B')
    c = IssuePriority.create!(:name => 'C')
    override = IssuePriority.create!(:name => 'BB', :parent_id => b.id)
    assert_equal [1, 2, 3, 2], [a, b, c, override].map {|e| e.reload.position}

    override.destroy
    assert_equal [1, 2, 3], [a, b, c].map {|e| e.reload.position}
  end

  def test_spaceship_operator_with_incomparable_value_should_return_nil
    e = Enumeration.first
    assert_nil e <=> nil
    assert_nil e <=> 'foo'
  end
end
