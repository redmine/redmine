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

require File.expand_path('../../test_helper', __FILE__)

class IssueNestedSetTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles,
           :trackers, :projects_trackers,
           :issue_statuses, :issue_categories, :issue_relations,
           :enumerations,
           :issues

  def test_create_root_issue
    issue1 = Issue.generate!
    issue2 = Issue.generate!
    issue1.reload
    issue2.reload

    assert_equal [issue1.id, nil, 1, 2], [issue1.root_id, issue1.parent_id, issue1.lft, issue1.rgt]
    assert_equal [issue2.id, nil, 1, 2], [issue2.root_id, issue2.parent_id, issue2.lft, issue2.rgt]
  end

  def test_create_child_issue
    parent = Issue.generate!
    child =  Issue.generate!(:parent_issue_id => parent.id)
    parent.reload
    child.reload

    assert_equal [parent.id, nil, 1, 4], [parent.root_id, parent.parent_id, parent.lft, parent.rgt]
    assert_equal [parent.id, parent.id, 2, 3], [child.root_id, child.parent_id, child.lft, child.rgt]
  end

  def test_creating_a_child_in_a_subproject_should_validate
    issue = Issue.generate!
    child = Issue.new(:project_id => 3, :tracker_id => 2, :author_id => 1,
                      :subject => 'child', :parent_issue_id => issue.id)
    assert_save child
    assert_equal issue, child.reload.parent
  end

  def test_creating_a_child_in_an_invalid_project_should_not_validate
    issue = Issue.generate!
    child = Issue.new(:project_id => 2, :tracker_id => 1, :author_id => 1,
                      :subject => 'child', :parent_issue_id => issue.id)
    assert !child.save
    assert_not_nil child.errors[:parent_issue_id]
  end

  def test_move_a_root_to_child
    parent1 = Issue.generate!
    parent2 = Issue.generate!
    child = Issue.generate!(:parent_issue_id => parent1.id)

    parent2.parent_issue_id = parent1.id
    parent2.save!
    child.reload
    parent1.reload
    parent2.reload

    assert_equal [parent1.id, 1, 6], [parent1.root_id, parent1.lft, parent1.rgt]
    assert_equal [parent1.id, 4, 5], [parent2.root_id, parent2.lft, parent2.rgt]
    assert_equal [parent1.id, 2, 3], [child.root_id, child.lft, child.rgt]
  end

  def test_move_a_child_to_root
    parent1 = Issue.generate!
    parent2 = Issue.generate!
    child =   Issue.generate!(:parent_issue_id => parent1.id)

    child.parent_issue_id = nil
    child.save!
    child.reload
    parent1.reload
    parent2.reload

    assert_equal [parent1.id, 1, 2], [parent1.root_id, parent1.lft, parent1.rgt]
    assert_equal [parent2.id, 1, 2], [parent2.root_id, parent2.lft, parent2.rgt]
    assert_equal [child.id, 1, 2], [child.root_id, child.lft, child.rgt]
  end

  def test_move_a_child_to_another_issue
    parent1 = Issue.generate!
    parent2 = Issue.generate!
    child =   Issue.generate!(:parent_issue_id => parent1.id)

    child.parent_issue_id = parent2.id
    child.save!
    child.reload
    parent1.reload
    parent2.reload

    assert_equal [parent1.id, 1, 2], [parent1.root_id, parent1.lft, parent1.rgt]
    assert_equal [parent2.id, 1, 4], [parent2.root_id, parent2.lft, parent2.rgt]
    assert_equal [parent2.id, 2, 3], [child.root_id, child.lft, child.rgt]
  end

  def test_move_a_child_with_descendants_to_another_issue
    parent1 = Issue.generate!
    parent2 = Issue.generate!
    child =   Issue.generate!(:parent_issue_id => parent1.id)
    grandchild = Issue.generate!(:parent_issue_id => child.id)

    parent1.reload
    parent2.reload
    child.reload
    grandchild.reload

    assert_equal [parent1.id, 1, 6], [parent1.root_id, parent1.lft, parent1.rgt]
    assert_equal [parent2.id, 1, 2], [parent2.root_id, parent2.lft, parent2.rgt]
    assert_equal [parent1.id, 2, 5], [child.root_id, child.lft, child.rgt]
    assert_equal [parent1.id, 3, 4], [grandchild.root_id, grandchild.lft, grandchild.rgt]

    child.reload.parent_issue_id = parent2.id
    child.save!
    child.reload
    grandchild.reload
    parent1.reload
    parent2.reload

    assert_equal [parent1.id, 1, 2], [parent1.root_id, parent1.lft, parent1.rgt]
    assert_equal [parent2.id, 1, 6], [parent2.root_id, parent2.lft, parent2.rgt]
    assert_equal [parent2.id, 2, 5], [child.root_id, child.lft, child.rgt]
    assert_equal [parent2.id, 3, 4], [grandchild.root_id, grandchild.lft, grandchild.rgt]
  end

  def test_move_a_child_with_descendants_to_another_project
    parent1 = Issue.generate!
    child =   Issue.generate!(:parent_issue_id => parent1.id)
    grandchild = Issue.generate!(:parent_issue_id => child.id)

    child.reload
    child.project = Project.find(2)
    assert child.save
    child.reload
    grandchild.reload
    parent1.reload

    assert_equal [1, parent1.id, 1, 2], [parent1.project_id, parent1.root_id, parent1.lft, parent1.rgt]
    assert_equal [2, child.id, 1, 4], [child.project_id, child.root_id, child.lft, child.rgt]
    assert_equal [2, child.id, 2, 3], [grandchild.project_id, grandchild.root_id, grandchild.lft, grandchild.rgt]
  end

  def test_moving_an_issue_to_a_descendant_should_not_validate
    parent1 = Issue.generate!
    parent2 = Issue.generate!
    child =   Issue.generate!(:parent_issue_id => parent1.id)
    grandchild = Issue.generate!(:parent_issue_id => child.id)

    child.reload
    child.parent_issue_id = grandchild.id
    assert !child.save
    assert_not_nil child.errors[:parent_issue_id]
  end

  def test_destroy_should_destroy_children
    issue1 = Issue.generate!
    issue2 = Issue.generate!
    issue3 = Issue.generate!(:parent_issue_id => issue2.id)
    issue4 = Issue.generate!(:parent_issue_id => issue1.id)

    issue3.init_journal(User.find(2))
    issue3.subject = 'child with journal'
    issue3.save!

    assert_difference 'Issue.count', -2 do
      assert_difference 'Journal.count', -1 do
        assert_difference 'JournalDetail.count', -1 do
          Issue.find(issue2.id).destroy
        end
      end
    end

    issue1.reload
    issue4.reload
    assert !Issue.exists?(issue2.id)
    assert !Issue.exists?(issue3.id)
    assert_equal [issue1.id, 1, 4], [issue1.root_id, issue1.lft, issue1.rgt]
    assert_equal [issue1.id, 2, 3], [issue4.root_id, issue4.lft, issue4.rgt]
  end
  
  def test_destroy_child_should_update_parent
    issue = Issue.generate!
    child1 = Issue.generate!(:parent_issue_id => issue.id)
    child2 = Issue.generate!(:parent_issue_id => issue.id)
    
    issue.reload
    assert_equal [issue.id, 1, 6], [issue.root_id, issue.lft, issue.rgt]
    
    child2.reload.destroy
    
    issue.reload
    assert_equal [issue.id, 1, 4], [issue.root_id, issue.lft, issue.rgt]
  end

  def test_destroy_parent_issue_updated_during_children_destroy
    parent = Issue.generate!
    Issue.generate!(:start_date => Date.today, :parent_issue_id => parent.id)
    Issue.generate!(:start_date => 2.days.from_now, :parent_issue_id => parent.id)

    assert_difference 'Issue.count', -3 do
      Issue.find(parent.id).destroy
    end
  end

  def test_destroy_child_issue_with_children
    root = Issue.create!(:project_id => 1, :author_id => 2, :tracker_id => 1, :subject => 'root')
    child = Issue.create!(:project_id => 1, :author_id => 2, :tracker_id => 1, :subject => 'child', :parent_issue_id => root.id)
    leaf = Issue.create!(:project_id => 1, :author_id => 2, :tracker_id => 1, :subject => 'leaf', :parent_issue_id => child.id)
    leaf.init_journal(User.find(2))
    leaf.subject = 'leaf with journal'
    leaf.save!

    assert_difference 'Issue.count', -2 do
      assert_difference 'Journal.count', -1 do
        assert_difference 'JournalDetail.count', -1 do
          Issue.find(child.id).destroy
        end
      end
    end

    root = Issue.find(root.id)
    assert root.leaf?, "Root issue is not a leaf (lft: #{root.lft}, rgt: #{root.rgt})"
  end

  def test_destroy_issue_with_grand_child
    parent = Issue.generate!
    issue = Issue.generate!(:parent_issue_id => parent.id)
    child = Issue.generate!(:parent_issue_id => issue.id)
    grandchild1 = Issue.generate!(:parent_issue_id => child.id)
    grandchild2 = Issue.generate!(:parent_issue_id => child.id)

    assert_difference 'Issue.count', -4 do
      Issue.find(issue.id).destroy
      parent.reload
      assert_equal [1, 2], [parent.lft, parent.rgt]
    end
  end

  def test_parent_priority_should_be_the_highest_child_priority
    parent = Issue.generate!(:priority => IssuePriority.find_by_name('Normal'))
    # Create children
    child1 = Issue.generate!(:priority => IssuePriority.find_by_name('High'), :parent_issue_id => parent.id)
    assert_equal 'High', parent.reload.priority.name
    child2 = Issue.generate!(:priority => IssuePriority.find_by_name('Immediate'), :parent_issue_id => child1.id)
    assert_equal 'Immediate', child1.reload.priority.name
    assert_equal 'Immediate', parent.reload.priority.name
    child3 = Issue.generate!(:priority => IssuePriority.find_by_name('Low'), :parent_issue_id => parent.id)
    assert_equal 'Immediate', parent.reload.priority.name
    # Destroy a child
    child1.destroy
    assert_equal 'Low', parent.reload.priority.name
    # Update a child
    child3.reload.priority = IssuePriority.find_by_name('Normal')
    child3.save!
    assert_equal 'Normal', parent.reload.priority.name
  end

  def test_parent_dates_should_be_lowest_start_and_highest_due_dates
    parent = Issue.generate!
    Issue.generate!(:start_date => '2010-01-25', :due_date => '2010-02-15', :parent_issue_id => parent.id)
    Issue.generate!(                             :due_date => '2010-02-13', :parent_issue_id => parent.id)
    Issue.generate!(:start_date => '2010-02-01', :due_date => '2010-02-22', :parent_issue_id => parent.id)
    parent.reload
    assert_equal Date.parse('2010-01-25'), parent.start_date
    assert_equal Date.parse('2010-02-22'), parent.due_date
  end

  def test_parent_done_ratio_should_be_average_done_ratio_of_leaves
    parent = Issue.generate!
    Issue.generate!(:done_ratio => 20, :parent_issue_id => parent.id)
    assert_equal 20, parent.reload.done_ratio
    Issue.generate!(:done_ratio => 70, :parent_issue_id => parent.id)
    assert_equal 45, parent.reload.done_ratio

    child = Issue.generate!(:done_ratio => 0, :parent_issue_id => parent.id)
    assert_equal 30, parent.reload.done_ratio

    Issue.generate!(:done_ratio => 30, :parent_issue_id => child.id)
    assert_equal 30, child.reload.done_ratio
    assert_equal 40, parent.reload.done_ratio
  end

  def test_parent_done_ratio_should_be_weighted_by_estimated_times_if_any
    parent = Issue.generate!
    Issue.generate!(:estimated_hours => 10, :done_ratio => 20, :parent_issue_id => parent.id)
    assert_equal 20, parent.reload.done_ratio
    Issue.generate!(:estimated_hours => 20, :done_ratio => 50, :parent_issue_id => parent.id)
    assert_equal (50 * 20 + 20 * 10) / 30, parent.reload.done_ratio
  end

  def test_parent_estimate_should_be_sum_of_leaves
    parent = Issue.generate!
    Issue.generate!(:estimated_hours => nil, :parent_issue_id => parent.id)
    assert_equal nil, parent.reload.estimated_hours
    Issue.generate!(:estimated_hours => 5, :parent_issue_id => parent.id)
    assert_equal 5, parent.reload.estimated_hours
    Issue.generate!(:estimated_hours => 7, :parent_issue_id => parent.id)
    assert_equal 12, parent.reload.estimated_hours
  end

  def test_move_parent_updates_old_parent_attributes
    first_parent = Issue.generate!
    second_parent = Issue.generate!
    child = Issue.generate!(:estimated_hours => 5, :parent_issue_id => first_parent.id)
    assert_equal 5, first_parent.reload.estimated_hours
    child.update_attributes(:estimated_hours => 7, :parent_issue_id => second_parent.id)
    assert_equal 7, second_parent.reload.estimated_hours
    assert_nil first_parent.reload.estimated_hours
  end

  def test_reschuling_a_parent_should_reschedule_subtasks
    parent = Issue.generate!
    c1 = Issue.generate!(:start_date => '2010-05-12', :due_date => '2010-05-18', :parent_issue_id => parent.id)
    c2 = Issue.generate!(:start_date => '2010-06-03', :due_date => '2010-06-10', :parent_issue_id => parent.id)
    parent.reload
    parent.reschedule_on!(Date.parse('2010-06-02'))
    c1.reload
    assert_equal [Date.parse('2010-06-02'), Date.parse('2010-06-08')], [c1.start_date, c1.due_date]
    c2.reload
    assert_equal [Date.parse('2010-06-03'), Date.parse('2010-06-10')], [c2.start_date, c2.due_date] # no change
    parent.reload
    assert_equal [Date.parse('2010-06-02'), Date.parse('2010-06-10')], [parent.start_date, parent.due_date]
  end

  def test_project_copy_should_copy_issue_tree
    p = Project.create!(:name => 'Tree copy', :identifier => 'tree-copy', :tracker_ids => [1, 2])
    i1 = Issue.generate!(:project => p, :subject => 'i1')
    i2 = Issue.generate!(:project => p, :subject => 'i2', :parent_issue_id => i1.id)
    i3 = Issue.generate!(:project => p, :subject => 'i3', :parent_issue_id => i1.id)
    i4 = Issue.generate!(:project => p, :subject => 'i4', :parent_issue_id => i2.id)
    i5 = Issue.generate!(:project => p, :subject => 'i5')
    c = Project.new(:name => 'Copy', :identifier => 'copy', :tracker_ids => [1, 2])
    c.copy(p, :only => 'issues')
    c.reload

    assert_equal 5, c.issues.count
    ic1, ic2, ic3, ic4, ic5 = c.issues.order('subject').all
    assert ic1.root?
    assert_equal ic1, ic2.parent
    assert_equal ic1, ic3.parent
    assert_equal ic2, ic4.parent
    assert ic5.root?
  end
end
