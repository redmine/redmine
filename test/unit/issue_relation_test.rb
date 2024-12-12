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

class IssueRelationTest < ActiveSupport::TestCase
  include Redmine::I18n

  def setup
    User.current = nil
  end

  def test_create
    from = Issue.find(1)
    to = Issue.find(2)

    relation = IssueRelation.new :issue_from => from, :issue_to => to,
                                 :relation_type => IssueRelation::TYPE_PRECEDES
    assert relation.save
    relation.reload
    assert_equal IssueRelation::TYPE_PRECEDES, relation.relation_type
    assert_equal from, relation.issue_from
    assert_equal to, relation.issue_to
  end

  def test_create_minimum
    relation = IssueRelation.new :issue_from => Issue.find(1), :issue_to => Issue.find(2)
    assert relation.save
    assert_equal IssueRelation::TYPE_RELATES, relation.relation_type
  end

  def test_follows_relation_should_be_reversed
    from = Issue.find(1)
    to = Issue.find(2)

    relation = IssueRelation.new :issue_from => from, :issue_to => to,
                                 :relation_type => IssueRelation::TYPE_FOLLOWS
    assert relation.save
    relation.reload
    assert_equal IssueRelation::TYPE_PRECEDES, relation.relation_type
    assert_equal to, relation.issue_from
    assert_equal from, relation.issue_to
  end

  def test_cannot_create_inverse_relates_relations
    from = Issue.find(1)
    to = Issue.find(2)

    relation1 = IssueRelation.new :issue_from => from, :issue_to => to,
                                  :relation_type => IssueRelation::TYPE_RELATES
    assert relation1.save

    relation2 = IssueRelation.new :issue_from => to, :issue_to => from,
                                  :relation_type => IssueRelation::TYPE_RELATES
    assert !relation2.save
    assert_not_equal [], relation2.errors[:base]
  end

  def test_follows_relation_should_not_be_reversed_if_validation_fails
    from = Issue.find(1)
    to = Issue.find(2)

    relation = IssueRelation.new :issue_from => from, :issue_to => to,
                                 :relation_type => IssueRelation::TYPE_FOLLOWS,
                                 :delay => 'xx'
    assert !relation.save
    assert_equal IssueRelation::TYPE_FOLLOWS, relation.relation_type
    assert_equal from, relation.issue_from
    assert_equal to, relation.issue_to
  end

  def test_relation_type_for
    from = Issue.find(1)
    to = Issue.find(2)

    relation = IssueRelation.new :issue_from => from, :issue_to => to,
                                 :relation_type => IssueRelation::TYPE_PRECEDES
    assert_equal IssueRelation::TYPE_PRECEDES, relation.relation_type_for(from)
    assert_equal IssueRelation::TYPE_FOLLOWS, relation.relation_type_for(to)
  end

  def test_set_issue_to_dates_without_issue_to
    r = IssueRelation.new(:issue_from => Issue.new(:start_date => Date.today),
                          :relation_type => IssueRelation::TYPE_PRECEDES,
                          :delay => 1)
    assert_nil r.set_issue_to_dates
  end

  def test_set_issue_to_dates_without_issues
    r = IssueRelation.new(:relation_type => IssueRelation::TYPE_PRECEDES, :delay => 1)
    assert_nil r.set_issue_to_dates
  end

  def test_validates_circular_dependency
    IssueRelation.delete_all
    assert(
      IssueRelation.create!(
        :issue_from => Issue.find(1), :issue_to => Issue.find(2),
        :relation_type => IssueRelation::TYPE_PRECEDES
      )
    )
    assert(
      IssueRelation.create!(
        :issue_from => Issue.find(2), :issue_to => Issue.find(3),
        :relation_type => IssueRelation::TYPE_PRECEDES
      )
    )
    r =
      IssueRelation.new(
        :issue_from => Issue.find(3), :issue_to => Issue.find(1),
        :relation_type => IssueRelation::TYPE_PRECEDES
      )
    assert !r.save
    assert_not_equal [], r.errors[:base]
  end

  def test_validates_circular_dependency_of_subtask
    set_language_if_valid 'en'
    issue1 = Issue.generate!
    issue2 = Issue.generate!
    IssueRelation.create!(
      :issue_from => issue1, :issue_to => issue2,
      :relation_type => IssueRelation::TYPE_PRECEDES
    )
    child = Issue.generate!(:parent_issue_id => issue2.id)
    issue1.reload
    child.reload
    r =
      IssueRelation.new(
        :issue_from => child, :issue_to => issue1,
        :relation_type => IssueRelation::TYPE_PRECEDES
      )
    assert !r.save
    assert_include 'This relation would create a circular dependency', r.errors.full_messages
  end

  def test_subtasks_should_allow_precedes_relation
    parent = Issue.generate!
    child1 = Issue.generate!(:parent_issue_id => parent.id)
    child2 = Issue.generate!(:parent_issue_id => parent.id)
    r =
      IssueRelation.new(
        :issue_from => child1, :issue_to => child2,
        :relation_type => IssueRelation::TYPE_PRECEDES
      )
    assert r.valid?
    assert r.save
  end

  def test_validates_circular_dependency_on_reverse_relations
    IssueRelation.delete_all
    assert(
      IssueRelation.create!(
        :issue_from => Issue.find(1), :issue_to => Issue.find(3),
        :relation_type => IssueRelation::TYPE_BLOCKS
      )
    )
    assert(
      IssueRelation.create!(
        :issue_from => Issue.find(1), :issue_to => Issue.find(2),
        :relation_type => IssueRelation::TYPE_BLOCKED
      )
    )
    r =
      IssueRelation.new(
        :issue_from => Issue.find(2), :issue_to => Issue.find(1),
        :relation_type => IssueRelation::TYPE_BLOCKED
      )
    assert !r.save
    assert_not_equal [], r.errors[:base]
  end

  def test_create_with_initialized_journals_should_create_journals
    from = Issue.find(1)
    to   = Issue.find(2)
    relation = IssueRelation.new(:issue_from => from, :issue_to => to,
                                 :relation_type => IssueRelation::TYPE_PRECEDES)
    relation.init_journals User.find(1)

    assert_difference(
      ->{ from.reload.journals.size } => +1,
      ->{ to.reload.journals.size } => +1
    ) do
      assert relation.save
    end

    from.journals.last.details.then do |details|
      assert details.exists?(property: 'relation', prop_key: 'precedes', value: '2')
    end

    to.journals.last.details.then do |details|
      assert_equal 3, details.count
      assert details.exists?(property: 'relation', prop_key: 'follows', value: '1', old_value: nil)
      assert details.exists?(property: 'attr', prop_key: 'due_date')
      assert details.exists?(property: 'attr', prop_key: 'start_date')
    end
  end

  def test_destroy_with_initialized_journals_should_create_journals
    relation = IssueRelation.find(1)
    from = relation.issue_from
    to   = relation.issue_to
    from_journals = from.journals.size
    to_journals   = to.journals.size
    relation.init_journals User.find(1)
    assert relation.destroy
    from.reload
    to.reload
    assert_equal from.journals.size, (from_journals + 1)
    assert_equal to.journals.size, (to_journals + 1)
    assert_equal 'relation', from.journals.last.details.last.property
    assert_equal 'blocks', from.journals.last.details.last.prop_key
    assert_equal '9', from.journals.last.details.last.old_value
    assert_nil   from.journals.last.details.last.value
    assert_equal 'relation', to.journals.last.details.last.property
    assert_equal 'blocked', to.journals.last.details.last.prop_key
    assert_equal '10', to.journals.last.details.last.old_value
    assert_nil   to.journals.last.details.last.value
  end

  def test_to_s_should_return_the_relation_string
    set_language_if_valid 'en'
    relation = IssueRelation.find(1)
    assert_equal "Blocks #9", relation.to_s(relation.issue_from)
    assert_equal "Blocked by #10", relation.to_s(relation.issue_to)
  end

  def test_to_s_without_argument_should_return_the_relation_string_for_issue_from
    set_language_if_valid 'en'
    relation = IssueRelation.find(1)
    assert_equal "Blocks #9", relation.to_s
  end

  def test_to_s_should_accept_a_block_as_custom_issue_formatting
    set_language_if_valid 'en'
    relation = IssueRelation.find(1)
    assert_equal "Blocks Bug #9", relation.to_s {|issue| "#{issue.tracker} ##{issue.id}"}
  end
end
