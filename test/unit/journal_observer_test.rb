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

class JournalObserverTest < ActiveSupport::TestCase
  def setup
    User.current = nil
    ActionMailer::Base.deliveries.clear
  end

  # context: issue_updated notified_events
  def test_create_should_send_email_notification_with_issue_updated
    issue = Issue.first
    user = User.first
    journal = issue.init_journal(user, "some notes")

    with_settings :notified_events => %w(issue_updated) do
      assert journal.save
    end
    assert_equal 2, ActionMailer::Base.deliveries.size
  end

  def test_create_should_not_send_email_notification_with_notify_set_to_false
    issue = Issue.first
    user = User.first
    journal = issue.init_journal(user, "some notes")
    journal.notify = false

    with_settings :notified_events => %w(issue_updated) do
      assert journal.save
    end
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def test_create_should_not_send_email_notification_without_issue_updated
    issue = Issue.first
    user = User.first
    journal = issue.init_journal(user, "some notes")

    with_settings :notified_events => [] do
      assert journal.save
    end
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def test_create_should_send_email_notification_with_issue_note_added
    issue = Issue.first
    user = User.first
    journal = issue.init_journal(user)
    journal.notes = 'This update has a note'

    with_settings :notified_events => %w(issue_note_added) do
      assert journal.save
    end
    assert_equal 2, ActionMailer::Base.deliveries.size
  end

  def test_create_should_not_send_email_notification_without_issue_note_added
    issue = Issue.first
    user = User.first
    journal = issue.init_journal(user)
    journal.notes = 'This update has a note'

    with_settings :notified_events => [] do
      assert journal.save
    end
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def test_create_should_send_email_notification_with_issue_status_updated
    issue = Issue.first
    user = User.first
    issue.init_journal(user)
    issue.status = IssueStatus.last

    with_settings :notified_events => %w(issue_status_updated) do
      assert issue.save
    end
    assert_equal 2, ActionMailer::Base.deliveries.size
  end

  def test_create_should_not_send_email_notification_without_issue_status_updated
    issue = Issue.first
    user = User.first
    issue.init_journal(user)
    issue.status = IssueStatus.last

    with_settings :notified_events => [] do
      assert issue.save
    end
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def test_create_without_status_update_should_not_send_email_notification_with_issue_status_updated
    issue = Issue.first
    user = User.first
    issue.init_journal(user)
    issue.subject = "No status update"

    with_settings :notified_events => %w(issue_status_updated) do
      assert issue.save
    end
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def test_create_should_send_email_notification_with_issue_assignee_updated
    issue = Issue.generate!(:assigned_to_id => 2)
    ActionMailer::Base.deliveries.clear
    user = User.first
    issue.init_journal(user)
    issue.assigned_to = User.find(3)

    with_settings :notified_events => %w(issue_assigned_to_updated) do
      assert issue.save
    end
    assert_equal 2, ActionMailer::Base.deliveries.size
  end

  def test_create_should_not_send_email_notification_without_issue_assignee_updated
    issue = Issue.generate!(:assigned_to_id => 2)
    ActionMailer::Base.deliveries.clear
    user = User.first
    issue.init_journal(user)
    issue.assigned_to = User.find(3)

    with_settings :notified_events => [] do
      assert issue.save
    end
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def test_create_should_send_email_notification_with_issue_priority_updated
    issue = Issue.first
    user = User.first
    issue.init_journal(user)
    issue.priority = IssuePriority.last

    with_settings :notified_events => %w(issue_priority_updated) do
      assert issue.save
    end
    assert_equal 2, ActionMailer::Base.deliveries.size
  end

  def test_create_should_not_send_email_notification_without_issue_priority_updated
    issue = Issue.first
    user = User.first
    issue.init_journal(user)
    issue.priority = IssuePriority.last

    with_settings :notified_events => [] do
      assert issue.save
    end
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def test_create_should_send_email_notification_with_issue_fixed_version_updated
    with_settings :notified_events => %w(issue_fixed_version_updated) do
      user = User.find_by_login('jsmith')
      issue = issues(:issues_001)
      issue.init_journal(user)
      issue.fixed_version = versions(:versions_003)

      assert issue.save
      assert_equal 2, ActionMailer::Base.deliveries.size
    end
  end

  def test_create_should_not_send_email_notification_without_issue_fixed_version_updated
    with_settings :notified_events => [] do
      user = User.find_by_login('jsmith')
      issue = issues(:issues_001)
      issue.init_journal(user)
      issue.fixed_version = versions(:versions_003)

      assert issue.save
      assert_equal 0, ActionMailer::Base.deliveries.size
    end
  end

  def test_create_should_send_email_notification_with_issue_attachment_added
    set_tmp_attachments_directory
    with_settings :notified_events => %w(issue_attachment_added) do
      user = User.find_by_login('jsmith')
      issue = issues(:issues_001)
      issue.init_journal(user)
      issue.save_attachments(
        { 'p0' => {'file' => mock_file_with_options(:original_filename => 'upload')} }
      )

      assert issue.save
      assert_equal 2, ActionMailer::Base.deliveries.size
    end
  end

  def test_create_should_not_send_email_notification_without_issue_attachment_added
    set_tmp_attachments_directory
    with_settings :notified_events => [] do
      user = User.find_by_login('jsmith')
      issue = issues(:issues_001)
      issue.init_journal(user)
      issue.save_attachments(
        { 'p0' => {'file' => mock_file_with_options(:original_filename => 'upload')} }
      )

      assert issue.save
      assert_equal 0, ActionMailer::Base.deliveries.size
    end
  end
end
