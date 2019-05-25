# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class ProjectNestedSetTest < ActiveSupport::TestCase

  def setup
    User.current = nil
    Project.delete_all
    Tracker.delete_all
    EnabledModule.delete_all

    @a = Project.create!(:name => 'A', :identifier => 'projecta')
    @a1 = Project.create!(:name => 'A1', :identifier => 'projecta1')
    @a1.set_parent!(@a)
    @a2 = Project.create!(:name => 'A2', :identifier => 'projecta2')
    @a2.set_parent!(@a)

    @c = Project.create!(:name => 'C', :identifier => 'projectc')
    @c1 = Project.create!(:name => 'C1', :identifier => 'projectc1')
    @c1.set_parent!(@c)

    @b = Project.create!(:name => 'B', :identifier => 'projectb')
    @b2 = Project.create!(:name => 'B2', :identifier => 'projectb2')
    @b2.set_parent!(@b)
    @b1 = Project.create!(:name => 'B1', :identifier => 'projectb1')
    @b1.set_parent!(@b)
    @b11 = Project.create!(:name => 'B11', :identifier => 'projectb11')
    @b11.set_parent!(@b1)
  end

  def test_valid_tree
    assert_valid_nested_set
  end

  def test_rebuild_should_build_valid_tree
    Project.update_all "lft = NULL, rgt = NULL"

    Project.rebuild_tree!
    assert_valid_nested_set
  end

  def test_rebuild_tree_should_build_valid_tree_even_with_valid_lft_rgt_values
    Project.where({:id => @a.id }).update_all("name = 'YY'")
    # lft and rgt values are still valid (Project.rebuild! would not update anything)
    # but projects are not ordered properly (YY is in the first place)

    Project.rebuild_tree!
    assert_valid_nested_set
  end

  def test_rebuild_without_projects_should_not_fail
    Project.delete_all
    assert Project.rebuild_tree!
  end

  def test_moving_a_child_to_a_different_parent_should_keep_valid_tree
    assert_no_difference 'Project.count' do
      Project.find_by_name('B1').set_parent!(Project.find_by_name('A2'))
    end
    assert_valid_nested_set
  end

  def test_renaming_a_root_to_first_position_should_update_nested_set_order
    @c.name = '1'
    @c.save!
    assert_valid_nested_set
  end

  def test_renaming_a_root_to_middle_position_should_update_nested_set_order
    @a.name = 'BA'
    @a.save!
    assert_valid_nested_set
  end

  def test_renaming_a_root_to_last_position_should_update_nested_set_order
    @a.name = 'D'
    @a.save!
    assert_valid_nested_set
  end

  def test_renaming_a_root_to_same_position_should_update_nested_set_order
    @c.name = 'D'
    @c.save!
    assert_valid_nested_set
  end

  def test_renaming_a_child_should_update_nested_set_order
    @a1.name = 'A3'
    @a1.save!
    assert_valid_nested_set
  end

  def test_renaming_a_child_with_child_should_update_nested_set_order
    @b1.name = 'B3'
    @b1.save!
    assert_valid_nested_set
  end

  def test_adding_a_root_to_first_position_should_update_nested_set_order
    project = Project.create!(:name => '1', :identifier => 'projectba')
    assert_valid_nested_set
  end

  def test_adding_a_root_to_middle_position_should_update_nested_set_order
    project = Project.create!(:name => 'BA', :identifier => 'projectba')
    assert_valid_nested_set
  end

  def test_adding_a_root_to_last_position_should_update_nested_set_order
    project = Project.create!(:name => 'Z', :identifier => 'projectba')
    assert_valid_nested_set
  end

  def test_destroying_a_root_with_children_should_keep_valid_tree
    assert_difference 'Project.count', -4 do
      Project.find_by_name('B').destroy
    end
    assert_valid_nested_set
  end

  def test_destroying_a_child_with_children_should_keep_valid_tree
    assert_difference 'Project.count', -2 do
      Project.find_by_name('B1').destroy
    end
    assert_valid_nested_set
  end

  private

  def assert_nested_set_values(h)
    assert Project.valid?
    h.each do |project, expected|
      project.reload
      assert_equal expected, [project.parent_id, project.lft, project.rgt], "Unexpected nested set values for #{project.name}"
    end
  end

  def assert_valid_nested_set
    projects = Project.all
    lft_rgt = projects.map {|p| [p.lft, p.rgt]}.flatten
    assert_equal projects.size * 2, lft_rgt.uniq.size
    assert_equal 1, lft_rgt.min
    assert_equal projects.size * 2, lft_rgt.max

    projects.each do |project|
      # lft should always be < rgt
      assert project.lft < project.rgt, "lft=#{project.lft} was not < rgt=#{project.rgt} for project #{project.name}"
      if project.parent_id
        # child lft/rgt values must be greater/lower
        assert_not_nil project.parent, "parent was nil for project #{project.name}"
        assert project.lft > project.parent.lft, "lft=#{project.lft} was not > parent.lft=#{project.parent.lft} for project #{project.name}"
        assert project.rgt < project.parent.rgt, "rgt=#{project.rgt} was not < parent.rgt=#{project.parent.rgt} for project #{project.name}"
      end
      # no overlapping lft/rgt values
      overlapping = projects.detect {|other|
        other != project && (
          (other.lft > project.lft && other.lft < project.rgt && other.rgt > project.rgt) ||
          (other.rgt > project.lft && other.rgt < project.rgt && other.lft < project.lft)
        )
      }
      assert_nil overlapping, (overlapping && "Project #{overlapping.name} (#{overlapping.lft}/#{overlapping.rgt}) overlapped #{project.name} (#{project.lft}/#{project.rgt})")
    end

    # root projects sorted alphabetically
    assert_equal Project.roots.map(&:name).sort, Project.roots.sort_by(&:lft).map(&:name), "Root projects were not properly sorted"
    projects.each do |project|
      if project.children.any?
        # sibling projects sorted alphabetically
        assert_equal project.children.map(&:name).sort, project.children.sort_by(&:lft).map(&:name), "Project #{project.name}'s children were not properly sorted"
      end
    end
  end
end
