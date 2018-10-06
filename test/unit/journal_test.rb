# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

class JournalTest < ActiveSupport::TestCase
  fixtures :projects, :issues, :issue_statuses, :journals, :journal_details,
           :issue_relations, :workflows,
           :users, :members, :member_roles, :roles, :enabled_modules,
           :groups_users, :email_addresses,
           :enumerations,
           :projects_trackers, :trackers, :custom_fields

  def setup
    @journal = Journal.find 1
    User.current = nil
  end

  def test_journalized_is_an_issue
    issue = @journal.issue
    assert_kind_of Issue, issue
    assert_equal 1, issue.id
  end

  def test_new_status
    status = @journal.new_status
    assert_not_nil status
    assert_kind_of IssueStatus, status
    assert_equal 2, status.id
  end

  def test_create_should_send_email_notification
    ActionMailer::Base.deliveries.clear
    issue = Issue.first
    user = User.first
    journal = issue.init_journal(user, issue)

    assert journal.save
    assert_equal 2, ActionMailer::Base.deliveries.size
  end

  def test_should_not_save_journal_with_blank_notes_and_no_details
    journal = Journal.new(:journalized => Issue.first, :user => User.first)

    assert_no_difference 'Journal.count' do
      assert_equal false, journal.save
    end
  end

  def test_create_should_not_split_non_private_notes
    assert_difference 'Journal.count' do
      assert_no_difference 'JournalDetail.count' do
        journal = Journal.generate!(:notes => 'Notes')
      end
    end

    assert_difference 'Journal.count' do
      assert_difference 'JournalDetail.count' do
        journal = Journal.generate!(:notes => 'Notes', :details => [JournalDetail.new])
      end
    end

    assert_difference 'Journal.count' do
      assert_difference 'JournalDetail.count' do
        journal = Journal.generate!(:notes => '', :details => [JournalDetail.new])
      end
    end
  end

  def test_create_should_split_private_notes
    assert_difference 'Journal.count' do
      assert_no_difference 'JournalDetail.count' do
        journal = Journal.generate!(:notes => 'Notes', :private_notes => true)
        journal.reload
        assert_equal true, journal.private_notes
        assert_equal 'Notes', journal.notes
      end
    end

    assert_difference 'Journal.count', 2 do
      assert_difference 'JournalDetail.count' do
        journal = Journal.generate!(:notes => 'Notes', :private_notes => true, :details => [JournalDetail.new])
        journal.reload
        assert_equal true, journal.private_notes
        assert_equal 'Notes', journal.notes
        assert_equal 0, journal.details.size

        journal_with_changes = Journal.order('id DESC').offset(1).first
        assert_equal false, journal_with_changes.private_notes
        assert_nil journal_with_changes.notes
        assert_equal 1, journal_with_changes.details.size
        assert_equal journal.created_on, journal_with_changes.created_on
      end
    end

    assert_difference 'Journal.count' do
      assert_difference 'JournalDetail.count' do
        journal = Journal.generate!(:notes => '', :private_notes => true, :details => [JournalDetail.new])
        journal.reload
        assert_equal false, journal.private_notes
        assert_equal '', journal.notes
        assert_equal 1, journal.details.size
      end
    end
  end

  def test_visible_scope_for_anonymous
    # Anonymous user should see issues of public projects only
    journals = Journal.visible(User.anonymous).to_a
    assert journals.any?
    assert_nil journals.detect {|journal| !journal.issue.project.is_public?}
    # Anonymous user should not see issues without permission
    Role.anonymous.remove_permission!(:view_issues)
    journals = Journal.visible(User.anonymous).to_a
    assert journals.empty?
  end

  def test_visible_scope_for_user
    user = User.find(9)
    assert user.projects.empty?
    # Non member user should see issues of public projects only
    journals = Journal.visible(user).to_a
    assert journals.any?
    assert_nil journals.detect {|journal| !journal.issue.project.is_public?}
    # Non member user should not see issues without permission
    Role.non_member.remove_permission!(:view_issues)
    user.reload
    journals = Journal.visible(user).to_a
    assert journals.empty?
    # User should see issues of projects for which user has view_issues permissions only
    Member.create!(:principal => user, :project_id => 1, :role_ids => [1])
    user.reload
    journals = Journal.visible(user).to_a
    assert journals.any?
    assert_nil journals.detect {|journal| journal.issue.project_id != 1}
  end

  def test_visible_scope_for_admin
    user = User.find(1)
    user.members.each(&:destroy)
    assert user.projects.empty?
    journals = Journal.visible(user).to_a
    assert journals.any?
    # Admin should see issues on private projects that admin does not belong to
    assert journals.detect {|journal| !journal.issue.project.is_public?}
  end

  def test_preload_journals_details_custom_fields_should_set_custom_field_instance_variable
    d = JournalDetail.new(:property => 'cf', :prop_key => '2')
    journals = [Journal.new(:details => [d])]

    d.expects(:instance_variable_set).with("@custom_field", CustomField.find(2)).once
    Journal.preload_journals_details_custom_fields(journals)
  end

  def test_preload_journals_details_custom_fields_with_empty_set
    assert_nothing_raised do
      Journal.preload_journals_details_custom_fields([])
    end
  end

  def test_details_should_normalize_dates
    j = JournalDetail.create!(:old_value => Date.parse('2012-11-03'), :value => Date.parse('2013-01-02'))
    j.reload
    assert_equal '2012-11-03', j.old_value
    assert_equal '2013-01-02', j.value
  end

  def test_details_should_normalize_true_values
    j = JournalDetail.create!(:old_value => true, :value => true)
    j.reload
    assert_equal '1', j.old_value
    assert_equal '1', j.value
  end

  def test_details_should_normalize_false_values
    j = JournalDetail.create!(:old_value => false, :value => false)
    j.reload
    assert_equal '0', j.old_value
    assert_equal '0', j.value
  end

  def test_custom_field_should_return_custom_field_for_cf_detail
    d = JournalDetail.new(:property => 'cf', :prop_key => '2')
    assert_equal CustomField.find(2), d.custom_field
  end

  def test_custom_field_should_return_nil_for_non_cf_detail
    d = JournalDetail.new(:property => 'subject')
    assert_nil d.custom_field
  end

  def test_visible_details_should_include_relations_to_visible_issues_only
    issue = Issue.generate!
    visible_issue = Issue.generate!
    hidden_issue = Issue.generate!(:is_private => true)

    journal = Journal.new
    journal.details << JournalDetail.new(:property => 'relation', :prop_key => 'relates', :value => visible_issue.id)
    journal.details << JournalDetail.new(:property => 'relation', :prop_key => 'relates', :value => hidden_issue.id)

    visible_details = journal.visible_details(User.anonymous)
    assert_equal 1, visible_details.size
    assert_equal visible_issue.id.to_s, visible_details.first.value.to_s

    visible_details = journal.visible_details(User.find(2))
    assert_equal 2, visible_details.size
  end
end
