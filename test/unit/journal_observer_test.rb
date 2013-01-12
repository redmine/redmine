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

class JournalObserverTest < ActiveSupport::TestCase
  fixtures :issues, :issue_statuses, :journals, :journal_details, :projects,
           :projects_trackers, :trackers, :enabled_modules, :enumerations,
           :users, :roles

  def setup
    ActionMailer::Base.deliveries.clear
    @journal = Journal.find 1
  end

  # context: issue_updated notified_events
  def test_create_should_send_email_notification_with_issue_updated
    issue = Issue.first
    user = User.first
    journal = issue.init_journal(user, issue)

    with_settings :notified_events => %w(issue_updated) do
      assert journal.save
    end
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  def test_create_should_not_send_email_notification_with_notify_set_to_false
    issue = Issue.first
    user = User.first
    journal = issue.init_journal(user, issue)
    journal.notify = false

    with_settings :notified_events => %w(issue_updated) do
      assert journal.save
    end
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def test_create_should_not_send_email_notification_without_issue_updated
    issue = Issue.first
    user = User.first
    journal = issue.init_journal(user, issue)

    with_settings :notified_events => [] do
      assert journal.save
    end
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  # context: issue_note_added notified_events
  def test_create_should_send_email_notification_with_issue_note_added
    issue = Issue.first
    user = User.first
    journal = issue.init_journal(user, issue)
    journal.notes = 'This update has a note'

    with_settings :notified_events => %w(issue_note_added) do
      assert journal.save
    end
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  def test_create_should_not_send_email_notification_without_issue_note_added
    issue = Issue.first
    user = User.first
    journal = issue.init_journal(user, issue)
    journal.notes = 'This update has a note'

    with_settings :notified_events => [] do
      assert journal.save
    end
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  # context: issue_status_updated notified_events
  def test_create_should_send_email_notification_with_issue_status_updated
    issue = Issue.first
    user = User.first
    issue.init_journal(user, issue)
    issue.status = IssueStatus.last

    with_settings :notified_events => %w(issue_status_updated) do
      assert issue.save
    end
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  def test_create_should_not_send_email_notification_without_issue_status_updated
    issue = Issue.first
    user = User.first
    issue.init_journal(user, issue)
    issue.status = IssueStatus.last

    with_settings :notified_events => [] do
      assert issue.save
    end
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  # context: issue_priority_updated notified_events
  def test_create_should_send_email_notification_with_issue_priority_updated
    issue = Issue.first
    user = User.first
    issue.init_journal(user, issue)
    issue.priority = IssuePriority.last

    with_settings :notified_events => %w(issue_priority_updated) do
      assert issue.save
    end
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  def test_create_should_not_send_email_notification_without_issue_priority_updated
    issue = Issue.first
    user = User.first
    issue.init_journal(user, issue)
    issue.priority = IssuePriority.last

    with_settings :notified_events => [] do
      assert issue.save
    end
    assert_equal 0, ActionMailer::Base.deliveries.size
  end
end
