# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

class MailerTest < ActiveSupport::TestCase
  include Redmine::I18n
  include Rails::Dom::Testing::Assertions
  fixtures :projects, :enabled_modules, :issues, :users, :email_addresses, :user_preferences, :members,
           :member_roles, :roles, :documents, :attachments, :news,
           :tokens, :journals, :journal_details, :changesets,
           :trackers, :projects_trackers,
           :custom_fields, :custom_fields_trackers,
           :issue_statuses, :enumerations, :messages, :boards, :repositories,
           :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions,
           :versions,
           :comments,
           :groups_users, :watchers

  def setup
    ActionMailer::Base.deliveries.clear
    Setting.plain_text_mail = '0'
    Setting.default_language = 'en'
    User.current = nil
  end

  def test_generated_links_in_emails
    with_settings :host_name => 'mydomain.foo', :protocol => 'https' do
      journal = Journal.find(3)
      assert Mailer.deliver_issue_edit(journal)
    end
    mail = last_email

    assert_select_email do
      # link to the main ticket on issue id
      assert_select 'a[href=?]',
                    'https://mydomain.foo/issues/2#change-3',
                    :text => '#2'
      # link to the main ticket
      assert_select 'a[href=?]',
                    'https://mydomain.foo/issues/2#change-3',
                    :text => 'Feature request #2: Add ingredients categories'
      # link to a referenced ticket
      assert_select 'a[href=?][title=?]',
                    'https://mydomain.foo/issues/1',
                    "Bug: Cannot print recipes (New)",
                    :text => '#1'
      # link to a changeset
      assert_select 'a[href=?][title=?]',
                    'https://mydomain.foo/projects/ecookbook/repository/10/revisions/2',
                    'This commit fixes #1, #2 and references #1 & #3',
                    :text => 'r2'
      # link to a description diff
      assert_select 'a[href^=?][title=?]',
                    # should be https://mydomain.foo/journals/diff/3?detail_id=4
                    # but the Rails 4.2 DOM assertion doesn't handle the ? in the
                    # attribute value
                    'https://mydomain.foo/journals/3/diff',
                    'View differences',
                    :text => 'diff'
      # link to an attachment
      assert_select 'a[href=?]',
                    'https://mydomain.foo/attachments/download/4/source.rb',
                    :text => 'source.rb'
    end
  end

  def test_generated_links_with_prefix
    relative_url_root = Redmine::Utils.relative_url_root
    with_settings :host_name => 'mydomain.foo/rdm', :protocol => 'http' do
      journal = Journal.find(3)
      assert Mailer.deliver_issue_edit(journal)
    end

    mail = last_email

    assert_select_email do
      # link to the main ticket
      assert_select 'a[href=?]',
                    'http://mydomain.foo/rdm/issues/2#change-3',
                    :text => 'Feature request #2: Add ingredients categories'
      # link to a referenced ticket
      assert_select 'a[href=?][title=?]',
                    'http://mydomain.foo/rdm/issues/1',
                    "Bug: Cannot print recipes (New)",
                    :text => '#1'
      # link to a changeset
      assert_select 'a[href=?][title=?]',
                    'http://mydomain.foo/rdm/projects/ecookbook/repository/10/revisions/2',
                    'This commit fixes #1, #2 and references #1 & #3',
                    :text => 'r2'
      # link to a description diff
      assert_select 'a[href^=?][title=?]',
                    # should be http://mydomain.foo/rdm/journals/diff/3?detail_id=4
                    # but the Rails 4.2 DOM assertion doesn't handle the ? in the
                    # attribute value
                    'http://mydomain.foo/rdm/journals/3/diff',
                    'View differences',
                    :text => 'diff'
      # link to an attachment
      assert_select 'a[href=?]',
                    'http://mydomain.foo/rdm/attachments/download/4/source.rb',
                    :text => 'source.rb'
    end
  end

  def test_generated_links_with_port_and_prefix
    with_settings :host_name => '10.0.0.1:81/redmine', :protocol => 'http' do
      Mailer.test_email(User.find(1)).deliver_now
      mail = last_email
      assert_include 'http://10.0.0.1:81/redmine', mail_body(mail)
    end
  end

  def test_generated_links_with_port
    with_settings :host_name => '10.0.0.1:81', :protocol => 'http' do
      Mailer.test_email(User.find(1)).deliver_now
      mail = last_email
      assert_include 'http://10.0.0.1:81', mail_body(mail)
    end
  end

  def test_issue_edit_should_generate_url_with_hostname_for_relations
    journal = Journal.new(:journalized => Issue.find(1), :user => User.find(1), :created_on => Time.now)
    journal.details << JournalDetail.new(:property => 'relation', :prop_key => 'label_relates_to', :value => 2)
    journal.save
    Mailer.deliver_issue_edit(journal)
    assert_not_nil last_email
    assert_select_email do
      assert_select 'a[href=?]', 'http://localhost:3000/issues/2', :text => 'Feature request #2'
    end
  end

  def test_generated_links_with_prefix_and_no_relative_url_root
    relative_url_root = Redmine::Utils.relative_url_root
    Redmine::Utils.relative_url_root = nil

    with_settings :host_name => 'mydomain.foo/rdm', :protocol => 'http' do
      journal = Journal.find(3)
      assert Mailer.deliver_issue_edit(journal)
    end

    mail = last_email

    assert_select_email do
      # link to the main ticket
      assert_select 'a[href=?]',
                    'http://mydomain.foo/rdm/issues/2#change-3',
                    :text => 'Feature request #2: Add ingredients categories'
      # link to a referenced ticket
      assert_select 'a[href=?][title=?]',
                    'http://mydomain.foo/rdm/issues/1',
                    "Bug: Cannot print recipes (New)",
                    :text => '#1'
      # link to a changeset
      assert_select 'a[href=?][title=?]',
                    'http://mydomain.foo/rdm/projects/ecookbook/repository/10/revisions/2',
                    'This commit fixes #1, #2 and references #1 & #3',
                    :text => 'r2'
      # link to a description diff
      assert_select 'a[href^=?][title=?]',
                    # should be http://mydomain.foo/rdm/journals/diff/3?detail_id=4
                    # but the Rails 4.2 DOM assertion doesn't handle the ? in the
                    # attribute value
                    'http://mydomain.foo/rdm/journals/3/diff',
                    'View differences',
                    :text => 'diff'
      # link to an attachment
      assert_select 'a[href=?]',
                    'http://mydomain.foo/rdm/attachments/download/4/source.rb',
                    :text => 'source.rb'
    end
  ensure
    # restore it
    Redmine::Utils.relative_url_root = relative_url_root
  end

  def test_link_to_user_in_email
    issue = Issue.generate!(:description => '@jsmith')
    assert Mailer.deliver_issue_add(issue)
    assert_select_email do
      assert_select "a[href=?]", "http://localhost:3000/users/2", :text => '@John Smith'
    end
  end

  def test_email_headers
    with_settings :mail_from => 'Redmine <redmine@example.net>' do
      issue = Issue.find(1)
      Mailer.deliver_issue_add(issue)
    end
    mail = last_email
    assert_equal 'All', mail.header['X-Auto-Response-Suppress'].to_s
    assert_equal 'auto-generated', mail.header['Auto-Submitted'].to_s
    # List-Id should not include the display name "Redmine"
    assert_equal '<redmine.example.net>', mail.header['List-Id'].to_s
    assert_equal 'Bug', mail.header['X-Redmine-Issue-Tracker'].to_s
  end

  def test_email_headers_should_include_sender
    issue = Issue.find(1)
    Mailer.deliver_issue_add(issue)
    mail = last_email
    assert_equal issue.author.login, mail.header['X-Redmine-Sender'].to_s
  end

  def test_email_headers_should_not_include_assignee_when_not_assigned
    issue = Issue.find(6)
    issue.init_journal(User.current)
    issue.update(:status_id => 4)
    issue.update(:assigned_to_id => nil)
    mail = last_email
    assert_not mail.header['X-Redmine-Issue-Assignee']
  end

  def test_email_headers_should_include_assignee_when_assigned
    issue = Issue.find(6)
    issue.init_journal(User.current)
    issue.update(:assigned_to_id => 2)
    mail = last_email
    assert_equal 'jsmith', mail.header['X-Redmine-Issue-Assignee'].to_s
  end

  def test_email_headers_should_include_assignee_if_assigned_to_group
    issue = Issue.find(6)
    with_settings :issue_group_assignment => 1 do
      issue.init_journal(User.current)
      issue.update(:assigned_to_id => 10)
    end
    mail = last_email
    assert_equal 'Group (A Team)', mail.header['X-Redmine-Issue-Assignee'].to_s
  end

  def test_plain_text_mail
    Setting.plain_text_mail = 1
    journal = Journal.find(2)
    Mailer.deliver_issue_edit(journal)
    mail = last_email
    assert_equal "text/plain; charset=UTF-8", mail.content_type
    assert_equal 0, mail.parts.size
    assert !mail.encoded.include?('href')
  end

  def test_html_mail
    Setting.plain_text_mail = 0
    journal = Journal.find(2)
    Mailer.deliver_issue_edit(journal)
    mail = last_email
    assert_equal 2, mail.parts.size
    assert mail.encoded.include?('href')
  end

  def test_from_header
    with_settings :mail_from => 'redmine@example.net' do
      Mailer.deliver_test_email(User.find(1))
    end
    mail = last_email
    assert_equal 'redmine@example.net', mail.from_addrs.first
  end

  def test_from_header_with_phrase
    with_settings :mail_from => 'Redmine app <redmine@example.net>' do
      Mailer.deliver_test_email(User.find(1))
    end
    mail = last_email
    assert_equal 'redmine@example.net', mail.from_addrs.first
    assert_equal 'Redmine app <redmine@example.net>', mail.header['From'].to_s
  end

  def test_from_header_with_rfc_non_compliant_phrase
    # Send out the email instead of raising an exception
    # no matter if the emission email address is not RFC compliant
    assert_nothing_raised do
      with_settings :mail_from => '[Redmine app] <redmine@example.net>' do
        Mailer.deliver_test_email(User.find(1))
      end
    end
    mail = last_email
    assert_match /<redmine@example\.net>/, mail.from_addrs.first
    assert_equal '[Redmine app] <redmine@example.net>', mail.header['From'].to_s
  end

  def test_from_header_with_author_name
    # Use the author's name or Setting.app_title as a display name
    # when Setting.mail_from does not include a display name
    with_settings :mail_from => 'redmine@example.net', :app_title => 'Foo' do
      # Use @author.name as a display name
      Issue.create!(:project_id => 1, :tracker_id => 1, :status_id => 5,
      :subject => 'Issue created by Dave Lopper', :author_id => 3)
      mail = last_email
      assert_equal 'redmine@example.net', mail.from_addrs.first
      assert_equal 'Dave Lopper <redmine@example.net>', mail.header['From'].to_s

      # Use app_title if @author is nil or AnonymousUser
      Mailer.deliver_test_email(User.find(1))
      mail = last_email
      assert_equal 'redmine@example.net', mail.from_addrs.first
      assert_equal "Foo <redmine@example.net>", mail.header['From'].to_s
    end
  end

  def test_should_not_send_email_without_recipient
    news = News.first
    user = news.author
    # Remove members except news author
    news.project.memberships.each {|m| m.destroy unless m.user == user}

    user.pref.no_self_notified = false
    user.pref.save
    User.current = user
    Mailer.deliver_news_added(news.reload)
    assert_equal 1, last_email.to.size

    # nobody to notify
    user.pref.no_self_notified = true
    user.pref.save
    User.current = user
    ActionMailer::Base.deliveries.clear
    Mailer.deliver_news_added(news.reload)
    assert ActionMailer::Base.deliveries.empty?
  end

  def test_issue_add_message_id
    issue = Issue.find(2)
    Mailer.deliver_issue_add(issue)
    mail = last_email
    uid = destination_user(mail).id
    assert_include "redmine.issue-2.20060719190421.#{uid}@example.net", mail.message_id
    assert_include "redmine.issue-2.20060719190421.#{uid}@example.net", mail.references
  end

  def test_issue_edit_message_id
    journal = Journal.find(3)
    journal.issue = Issue.find(2)

    Mailer.deliver_issue_edit(journal)
    mail = last_email
    uid = destination_user(mail).id
    assert_match /^redmine\.journal-3\.\d+\.#{uid}@example\.net/, mail.message_id
    assert_include "redmine.issue-2.20060719190421.#{uid}@example.net", mail.references
    assert_select_email do
      # link to the update
      assert_select "a[href=?]",
                    "http://localhost:3000/issues/#{journal.journalized_id}#change-#{journal.id}"
    end
  end

  def test_message_posted_message_id
    message = Message.find(1)
    attachment = message.attachments.first
    Mailer.deliver_message_posted(message)
    mail = last_email
    uid = destination_user(mail).id
    assert_include "redmine.message-1.20070512151532.#{uid}@example.net", mail.message_id
    assert_include "redmine.message-1.20070512151532.#{uid}@example.net", mail.references
    assert_select_email do
      # link to the message
      assert_select "a[href=?]",
                    "http://localhost:3000/boards/#{message.board.id}/topics/#{message.id}",
                    :text => message.subject
      # link to the attachments download
      assert_select 'fieldset.attachments' do
        assert_select 'a[href=?]',
                      "http://localhost:3000/attachments/download/#{attachment.id}/#{attachment.filename}",
                      :text => attachment.filename
      end
    end
  end

  def test_reply_posted_message_id
    set_tmp_attachments_directory
    message = Message.find(3)
    attachment = Attachment.generate!(
      :container => message,
      :file => uploaded_test_file('testfile.txt', 'text/plain')
    )
    Mailer.deliver_message_posted(message)
    mail = last_email
    uid = destination_user(mail).id
    assert_include "redmine.message-3.20070512151802.#{uid}@example.net", mail.message_id
    assert_include "redmine.message-1.20070512151532.#{uid}@example.net", mail.references
    assert_select_email do
      # link to the reply
      assert_select "a[href=?]",
                    "http://localhost:3000/boards/#{message.board.id}/topics/#{message.root.id}?r=#{message.id}#message-#{message.id}",
                    :text => message.subject
      # link to the attachments download
      assert_select 'fieldset.attachments' do
        assert_select 'a[href=?]',
                      "http://localhost:3000/attachments/download/#{attachment.id}/testfile.txt",
                      :text => 'testfile.txt'
      end
    end
  end

  def test_timestamp_in_message_id_should_be_utc
    zone_was = Time.zone
    issue = Issue.find(3)
    user = User.find(1)
    %w(UTC Paris Tokyo).each do |zone|
      Time.use_zone(zone) do
        assert_match /^redmine\.issue-3\.20060719190727\.1@example\.net/, Mailer.token_for(issue, user)
      end
    end
  end

  test "#issue_add should notify project members" do
    issue = Issue.find(1)
    assert Mailer.deliver_issue_add(issue)
    assert_include 'dlopper@somenet.foo', recipients
  end

  def test_issue_add_should_send_mail_to_all_user_email_address
    EmailAddress.create!(:user_id => 3, :address => 'otheremail@somenet.foo')
    issue = Issue.find(1)
    assert Mailer.deliver_issue_add(issue)

    assert mail = ActionMailer::Base.deliveries.find {|m| m.to.include?('dlopper@somenet.foo')}
    assert mail.to.include?('otheremail@somenet.foo')
  end

  test "#issue_add should not notify project members that are not allow to view the issue" do
    issue = Issue.find(1)
    Role.find(2).remove_permission!(:view_issues)
    assert Mailer.deliver_issue_add(issue)
    assert_not_include 'dlopper@somenet.foo', recipients
  end

  test "#issue_add should notify issue watchers" do
    issue = Issue.find(1)
    user = User.find(9)
    # minimal email notification options
    user.pref.no_self_notified = '1'
    user.pref.save
    user.mail_notification = false
    user.save

    Watcher.create!(:watchable => issue, :user => user)
    assert Mailer.deliver_issue_add(issue)
    assert_include user.mail, recipients
  end

  test "#issue_add should not notify watchers not allowed to view the issue" do
    issue = Issue.find(1)
    user = User.find(9)
    Watcher.create!(:watchable => issue, :user => user)
    Role.non_member.remove_permission!(:view_issues)
    assert Mailer.deliver_issue_add(issue)
    assert_not_include user.mail, recipients
  end

  def test_issue_add_should_notify_mentioned_users_in_issue_description
    User.find(1).mail_notification = 'only_my_events'

    issue = Issue.generate!(project_id: 1, description: 'Hello @dlopper and @admin.')

    assert Mailer.deliver_issue_add(issue)
    # @jsmith and @dlopper are members of the project
    # admin is mentioned
    # @dlopper won't receive duplicated notifications
    assert_equal 3, ActionMailer::Base.deliveries.size
    assert_include User.find(1).mail, recipients
  end

  def test_issue_add_should_include_enabled_fields
    issue = Issue.find(2)
    assert Mailer.deliver_issue_add(issue)
    assert_mail_body_match '* Target version: 1.0', last_email
    assert_select_email do
      assert_select 'li', :text => 'Target version: 1.0'
    end
  end

  def test_issue_add_should_not_include_disabled_fields
    issue = Issue.find(2)
    tracker = issue.tracker
    tracker.core_fields -= ['fixed_version_id', 'start_date']
    tracker.save!
    assert Mailer.deliver_issue_add(issue)
    assert_mail_body_no_match 'Target version', last_email
    assert_mail_body_no_match 'Start date', last_email
    assert_select_email do
      assert_select 'li', :text => /Target version/, :count => 0
      assert_select 'li', :text => /Start date/, :count => 0
    end
  end

  def test_issue_add_subject_should_include_status_if_setting_is_enabled
    with_settings :show_status_changes_in_mail_subject => 1 do
      issue = Issue.find(2)
      Mailer.deliver_issue_add(issue)

      mail = last_email
      assert_equal "[eCookbook - Feature request #2] (Assigned) Add ingredients categories", mail.subject
    end
  end

  def test_issue_add_subject_should_not_include_status_if_setting_is_disabled
    with_settings :show_status_changes_in_mail_subject => 0 do
      issue = Issue.find(2)
      Mailer.deliver_issue_add(issue)

      mail = last_email
      assert_equal "[eCookbook - Feature request #2] Add ingredients categories", mail.subject
    end
  end

  def test_issue_add_should_include_issue_status_type_badge
    issue = Issue.find(1)
    Mailer.deliver_issue_add(issue)

    mail = last_email
    assert_select_email do
      assert_select 'span.badge.badge-status-open', text: 'open'
    end
  end

  def test_issue_edit_subject_should_include_status_changes_if_setting_is_enabled
    with_settings :show_status_changes_in_mail_subject => 1 do
      issue = Issue.find(2)
      issue.init_journal(User.current)
      issue.update(:status_id => 4)
      journal = issue.journals.last
      Mailer.deliver_issue_edit(journal)

      assert journal.new_value_for('status_id')
      mail = last_email
      assert_equal "[eCookbook - Feature request #2] (Feedback) Add ingredients categories", mail.subject
    end
  end

  def test_issue_edit_subject_should_not_include_status_changes_if_setting_is_disabled
    with_settings :show_status_changes_in_mail_subject => 0 do
      issue = Issue.find(2)
      issue.init_journal(User.current)
      issue.update(:status_id => 4)
      journal = issue.journals.last
      Mailer.deliver_issue_edit(journal)

      assert journal.new_value_for('status_id')
      mail = last_email
      assert_equal "[eCookbook - Feature request #2] Add ingredients categories", mail.subject
    end
  end

  def test_issue_edit_should_send_private_notes_to_users_with_permission_only
    journal = Journal.find(1)
    journal.private_notes = true
    journal.save!

    Role.find(2).add_permission! :view_private_notes
    assert_difference 'ActionMailer::Base.deliveries.size', 2 do
      Mailer.deliver_issue_edit(journal)
    end
    assert_equal %w(dlopper@somenet.foo jsmith@somenet.foo), recipients
    ActionMailer::Base.deliveries.clear

    Role.find(2).remove_permission! :view_private_notes
    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      Mailer.deliver_issue_edit(journal)
    end
    assert_equal %w(jsmith@somenet.foo), recipients
  end

  def test_issue_edit_should_send_private_notes_to_watchers_with_permission_only
    Issue.find(1).set_watcher(User.find_by_login('someone'))
    journal = Journal.find(1)
    journal.private_notes = true
    journal.save!

    Role.non_member.add_permission! :view_private_notes
    Mailer.deliver_issue_edit(journal)
    assert_include 'someone@foo.bar', recipients
    ActionMailer::Base.deliveries.clear

    Role.non_member.remove_permission! :view_private_notes
    Mailer.deliver_issue_edit(journal)
    assert_not_include 'someone@foo.bar', recipients
  end

  def test_issue_edit_should_mark_private_notes
    journal = Journal.find(2)
    journal.private_notes = true
    journal.save!

    with_settings :default_language => 'en' do
      Mailer.deliver_issue_edit(journal)
    end
    assert_mail_body_match '(Private notes)', last_email
  end

  def test_issue_edit_with_relation_should_notify_users_who_can_see_the_related_issue
    issue = Issue.generate!
    issue.init_journal(User.find(1))
    private_issue = Issue.generate!(:is_private => true)
    IssueRelation.create!(:issue_from => issue, :issue_to => private_issue, :relation_type => 'relates')
    issue.reload
    assert_equal 1, issue.journals.size
    journal = issue.journals.first
    ActionMailer::Base.deliveries.clear

    Mailer.deliver_issue_edit(journal)
    recipients.each do |email|
      user = User.find_by_mail(email)
      assert private_issue.visible?(user), "Issue was not visible to #{user}"
    end
  end

  def test_issue_edit_should_notify_mentioned_users_in_issue_updated_description
    User.find(1).mail_notification = 'only_my_events'

    issue = Issue.find(3)
    issue.init_journal(User.current)
    issue.update(description: "Hello @admin")
    journal = issue.journals.last

    ActionMailer::Base.deliveries.clear
    Mailer.deliver_issue_edit(journal)

    # @jsmith and @dlopper are members of the project
    # admin is mentioned in the updated description
    # @dlopper won't receive duplicated notifications
    assert_equal 3, ActionMailer::Base.deliveries.size
    assert_include User.find(1).mail, recipients
  end

  def test_issue_edit_should_notify_mentioned_users_in_notes
    User.find(1).mail_notification = 'only_my_events'

    journal = Journal.generate!(journalized: Issue.find(3), user: User.find(1), notes: 'Hello @admin.')

    ActionMailer::Base.deliveries.clear
    Mailer.deliver_issue_edit(journal)

    # @jsmith and @dlopper are members of the project
    # admin is mentioned in the notes
    # @dlopper won't receive duplicated notifications
    assert_equal 3, ActionMailer::Base.deliveries.size
    assert_include User.find(1).mail, recipients
  end

  def test_issue_should_send_email_notification_with_suppress_empty_fields
    ActionMailer::Base.deliveries.clear
    with_settings :notified_events => %w(issue_added) do
      cf = IssueCustomField.generate!
      issue = Issue.generate!
      Mailer.deliver_issue_add(issue)

      assert_not_equal 0, ActionMailer::Base.deliveries.size

      mail = last_email
      assert_mail_body_match /^\* Author: /, mail
      assert_mail_body_match /^\* Status: /, mail
      assert_mail_body_match /^\* Priority: /, mail

      assert_mail_body_no_match /^\* Assignee: /, mail
      assert_mail_body_no_match /^\* Category: /, mail
      assert_mail_body_no_match /^\* Target version: /, mail
      assert_mail_body_no_match /^\* #{cf.name}: /, mail
    end
  end

  def test_locked_user_in_group_watcher_should_not_be_notified
    locked_user = users(:users_005)
    group = Group.generate!
    group.users << locked_user
    issue = Issue.generate!
    Watcher.create!(:watchable => issue, :user => group)

    ActionMailer::Base.deliveries.clear
    assert Mailer.deliver_issue_add(issue)
    assert_not_include locked_user.mail, recipients

    journal = issue.init_journal(User.current)
    issue.update(:status_id => 4)
    ActionMailer::Base.deliveries.clear
    Mailer.deliver_issue_edit(journal)
    assert_not_include locked_user.mail, recipients
  end

  def test_version_file_added
    attachements = [Attachment.find_by_container_type('Version')]
    assert Mailer.deliver_attachments_added(attachements)
    assert_not_nil last_email.to
    assert last_email.to.any?
    assert_select_email do
      assert_select "a[href=?]", "http://localhost:3000/projects/ecookbook/files"
    end
  end

  def test_project_file_added
    attachements = [Attachment.find_by_container_type('Project')]
    assert Mailer.deliver_attachments_added(attachements)
    assert_not_nil last_email.to
    assert last_email.to.any?
    assert_select_email do
      assert_select "a[href=?]", "http://localhost:3000/projects/ecookbook/files"
    end
  end

  def test_news_added_should_notify_project_news_watchers
    set_tmp_attachments_directory
    user1 = User.generate!
    user2 = User.generate!
    news = News.find(1)
    news.project.enabled_module('news').add_watcher(user1)
    attachment = Attachment.generate!(
      :container => news,
      :file => uploaded_test_file('testfile.txt', 'text/plain')
    )

    Mailer.deliver_news_added(news)
    assert_include user1.mail, recipients
    assert_not_include user2.mail, recipients
    assert_select_email do
      # link to the attachments download
      assert_select 'fieldset.attachments' do
        assert_select 'a[href=?]',
                      "http://localhost:3000/attachments/download/#{attachment.id}/testfile.txt",
                      :text => 'testfile.txt'
      end
    end
  end

  def test_wiki_content_added
    content = WikiContent.find(1)
    assert_difference 'ActionMailer::Base.deliveries.size', 2 do
      assert Mailer.deliver_wiki_content_added(content)
      assert_select_email do
        assert_select 'a[href=?]',
                      'http://localhost:3000/projects/ecookbook/wiki/CookBook_documentation',
                      :text => 'CookBook documentation'
      end
    end
  end

  def test_wiki_content_added_should_notify_mentioned_users_in_content
    content = WikiContent.new(text: 'Hello @admin.', author_id: 1, page_id: 1)
    content.save!

    ActionMailer::Base.deliveries.clear
    Mailer.deliver_wiki_content_added(content)

    # @jsmith and @dlopper are members of the project
    # admin is mentioned in the notes
    # @dlopper won't receive duplicated notifications
    assert_equal 3, ActionMailer::Base.deliveries.size
    assert_include User.find(1).mail, recipients
  end

  def test_wiki_content_updated
    content = WikiContent.find(1)
    assert Mailer.deliver_wiki_content_updated(content)
    assert_select_email do
      assert_select 'a[href=?]',
                    'http://localhost:3000/projects/ecookbook/wiki/CookBook_documentation',
                    :text => 'CookBook documentation'
    end
  end

  def test_wiki_content_updated_should_notify_mentioned_users_in_updated_content
    content = WikiContent.find(1)
    content.update(text: 'Hello @admin.')
    content.save!

    ActionMailer::Base.deliveries.clear
    Mailer.deliver_wiki_content_updated(content)

    # @jsmith and @dlopper are members of the project
    # admin is mentioned in the notes
    # @dlopper won't receive duplicated notifications
    assert_equal 3, ActionMailer::Base.deliveries.size
    assert_include User.find(1).mail, recipients
  end

  def test_register
    token = Token.find(1)
    assert Mailer.deliver_register(token.user, token)
    assert_select_email do
      assert_select "a[href=?]",
                    "http://localhost:3000/account/activate?token=#{token.value}",
                    :text => "http://localhost:3000/account/activate?token=#{token.value}"
    end
  end

  def test_test_email_later
    user = User.find(1)
    assert Mailer.test_email(user).deliver_later
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  def test_reminders
    users(:users_003).pref.update_attribute :time_zone, 'UTC' # dlopper
    days = 42
    Mailer.reminders(:days => days)
    assert_equal 1, ActionMailer::Base.deliveries.size
    mail = last_email
    assert mail.to.include?('dlopper@somenet.foo')
    assert_mail_body_match 'Bug #3: Error 281 when updating a recipe (5 days late)', mail
    assert_mail_body_match 'View all issues (2 open)', mail
    url =
      "http://localhost:3000/issues?f%5B%5D=status_id&f%5B%5D=assigned_to_id" \
        "&f%5B%5D=due_date&op%5Bassigned_to_id%5D=%3D&op%5Bdue_date%5D=%3Ct%2B&op%5B" \
        "status_id%5D=o&set_filter=1&sort=due_date%3Aasc&v%5B" \
        "assigned_to_id%5D%5B%5D=me&v%5Bdue_date%5D%5B%5D=#{days}"
    assert_select_email do
      assert_select 'a[href=?]',
                    url,
                    :text => '1'
      assert_select 'a[href=?]',
                    'http://localhost:3000/issues?assigned_to_id=me&set_filter=1&sort=due_date%3Aasc',
                    :text => 'View all issues'
      assert_select '/p:nth-last-of-type(1)', :text => 'View all issues (2 open)'
    end
    assert_equal "1 issue(s) due in the next #{days} days", mail.subject
  end

  def test_reminders_language_auto
    with_settings :default_language => 'fr' do
      user = User.find(3)
      user.update_attribute :language, ''
      user.pref.update_attribute :time_zone, 'UTC'
      Mailer.reminders(:days => 42)
      assert_equal 1, ActionMailer::Base.deliveries.size
      mail = last_email
      assert mail.to.include?('dlopper@somenet.foo')
      assert_mail_body_match(
        'Bug #3: Error 281 when updating a recipe (En retard de 5 jours)',
        mail
      )
      assert_equal "1 demande(s) arrivent à échéance (42)", mail.subject
    end
  end

  def test_reminders_should_not_include_closed_issues
    with_settings :default_language => 'en' do
      Issue.create!(:project_id => 1, :tracker_id => 1, :status_id => 5,
                      :subject => 'Closed issue', :assigned_to_id => 3,
                      :due_date => 5.days.from_now,
                      :author_id => 2)
      ActionMailer::Base.deliveries.clear

      Mailer.reminders(:days => 42)
      assert_equal 1, ActionMailer::Base.deliveries.size
      mail = last_email
      assert mail.to.include?('dlopper@somenet.foo')
      assert_mail_body_no_match 'Closed issue', mail
    end
  end

  def test_reminders_for_users
    users(:users_003).pref.update_attribute :time_zone, 'UTC' # dlopper
    Mailer.reminders(:days => 42, :users => ['5'])
    assert_equal 0, ActionMailer::Base.deliveries.size # No mail for dlopper
    Mailer.reminders(:days => 42, :users => ['3'])
    assert_equal 1, ActionMailer::Base.deliveries.size # No mail for dlopper
    mail = last_email
    assert mail.to.include?('dlopper@somenet.foo')
    assert_mail_body_match 'Bug #3: Error 281 when updating a recipe (5 days late)', mail
  end

  def test_reminder_should_include_issues_assigned_to_groups
    with_settings :default_language => 'en', :issue_group_assignment => '1' do
      group = Group.generate!
      Member.create!(:project_id => 1, :principal => group, :role_ids => [1])
      [users(:users_002), users(:users_003)].each do |user| # jsmith, dlopper
        group.users << user
        user.pref.update_attribute :time_zone, 'UTC'
      end

      Issue.update_all(:assigned_to_id => nil)
      due_date = 10.days.from_now
      Issue.update(1, :due_date => due_date, :assigned_to_id => 3)
      Issue.update(2, :due_date => due_date, :assigned_to_id => group.id)
      Issue.create!(:project_id => 1, :tracker_id => 1, :status_id => 1,
                      :subject => 'Assigned to group', :assigned_to => group,
                      :due_date => 5.days.from_now,
                      :author_id => 2)
      ActionMailer::Base.deliveries.clear

      Mailer.reminders(:days => 7)
      assert_equal 2, ActionMailer::Base.deliveries.size
      assert_equal %w(dlopper@somenet.foo jsmith@somenet.foo), recipients
      ActionMailer::Base.deliveries.each do |mail|
        assert_mail_body_match(
          '1 issue(s) that are assigned to you are due in the next 7 days::',
          mail
        )
        assert_mail_body_match 'Assigned to group (Due in 5 days)', mail
        assert_mail_body_match(
          "View all issues (#{mail.to.include?('dlopper@somenet.foo') ? 3 : 2} open)",
          mail
        )
      end
    end
  end

  def test_reminders_with_version_option
    with_settings :default_language => 'en' do
      version = Version.generate!(:name => 'Acme', :project_id => 1)
      Issue.generate!(:assigned_to => User.find(2), :due_date => 5.days.from_now)
      Issue.generate!(:assigned_to => User.find(3), :due_date => 5.days.from_now,
                      :fixed_version => version)
      ActionMailer::Base.deliveries.clear

      Mailer.reminders(:days => 42, :version => 'acme')
      assert_equal 1, ActionMailer::Base.deliveries.size
      assert_include 'dlopper@somenet.foo', recipients
    end
  end

  def test_reminders_should_only_include_issues_the_user_can_see
    with_settings :default_language => 'en' do
      user = User.find(3)
      member = Member.create!(:project_id => 2, :principal => user, :role_ids => [1])
      Issue.create!(:project_id => 2, :tracker_id => 1, :status_id => 1,
                      :subject => 'Issue dlopper should not see', :assigned_to_id => 3,
                      :due_date => 5.days.from_now,
                      :author_id => 2)
      member.destroy
      ActionMailer::Base.deliveries.clear

      Mailer.reminders(:days => 42)
      assert_equal 1, ActionMailer::Base.deliveries.size
      assert_include 'dlopper@somenet.foo', recipients
      mail = last_email
      assert_mail_body_no_match 'Issue dlopper should not see', mail
    end
  end

  def test_reminders_should_sort_issues_by_due_date
    user = User.find(2)
    user.pref.update_attribute :time_zone, 'UTC'
    Issue.generate!(:assigned_to => user, :due_date => 2.days.from_now, :subject => 'quux')
    Issue.generate!(:assigned_to => user, :due_date => 0.days.from_now, :subject => 'baz')
    Issue.generate!(:assigned_to => user, :due_date => 1.days.from_now, :subject => 'qux')
    Issue.generate!(:assigned_to => user, :due_date => -1.days.from_now, :subject => 'foo')
    Issue.generate!(:assigned_to => user, :due_date => -1.days.from_now, :subject => 'bar')
    ActionMailer::Base.deliveries.clear

    Mailer.reminders(:days => 7, :users => [user.id])
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_select_email do
      assert_select 'li', 5
      assert_select 'li:nth-child(1)', /foo \(1 day late\)/
      assert_select 'li:nth-child(2)', /bar \(1 day late\)/
      assert_select 'li:nth-child(3)', /baz \(Due in 0 days\)/
      assert_select 'li:nth-child(4)', /qux \(Due in 1 day\)/
      assert_select 'li:nth-child(5)', /quux \(Due in 2 days\)/
    end
  end

  def test_security_notification
    set_language_if_valid User.find(1).language
    with_settings :emails_footer => "footer without link" do
      sender = User.find(2)
      sender.remote_ip = '192.168.1.1'
      assert(
        Mailer.deliver_security_notification(
          User.find(1),
          sender,
          :message => :notice_account_password_updated
        )
      )
      mail = last_email
      assert_mail_body_match sender.login, mail
      assert_mail_body_match '192.168.1.1', mail
      assert_mail_body_match I18n.t(:notice_account_password_updated), mail
      assert_select_email do
        assert_select "h1", false
        assert_select "a", false
      end
    end
  end

  def test_security_notification_with_overridden_remote_ip
    set_language_if_valid User.find(1).language
    with_settings :emails_footer => "footer without link" do
      sender = User.find(2)
      sender.remote_ip = '192.168.1.1'
      assert(
        Mailer.deliver_security_notification(
          User.find(1),
          sender,
          :message => :notice_account_password_updated,
          :remote_ip => '10.0.0.42'
        )
      )
      mail = last_email
      assert_mail_body_match '10.0.0.42', mail
    end
  end

  def test_security_notification_should_include_title
    set_language_if_valid User.find(2).language
    with_settings :emails_footer => "footer without link" do
      assert(
        Mailer.deliver_security_notification(
          User.find(2), User.find(2),
          :message => :notice_account_password_updated,
          :title => :label_my_account
        )
      )
      assert_select_email do
        assert_select "a", false
        assert_select "h1", :text => I18n.t(:label_my_account)
      end
    end
  end

  def test_security_notification_should_include_link
    set_language_if_valid User.find(3).language
    with_settings :emails_footer => "footer without link" do
      assert(
        Mailer.deliver_security_notification(
          User.find(3), User.find(3),
          :message => :notice_account_password_updated,
          :title => :label_my_account,
          :url => {:controller => 'my', :action => 'account'}
        )
      )
      assert_select_email do
        assert_select "h1", false
        assert_select 'a[href=?]', 'http://localhost:3000/my/account', :text => I18n.t(:label_my_account)
      end
    end
  end

  def test_mailer_should_not_change_locale
    # Set current language to italian
    set_language_if_valid 'it'
    # Send an email to a french user
    user = User.find(1)
    user.update_attribute :language, 'fr'

    Mailer.deliver_account_activated(user)
    mail = last_email
    assert_mail_body_match 'Votre compte', mail

    assert_equal :it, current_language
  end

  def test_with_deliveries_off
    Mailer.with_deliveries false do
      Mailer.test_email(User.find(1)).deliver_now
    end
    assert ActionMailer::Base.deliveries.empty?
    # should restore perform_deliveries
    assert ActionMailer::Base.perform_deliveries
  end

  def test_token_for_should_strip_trailing_gt_from_address_with_full_name
    with_settings :mail_from => "Redmine Mailer<no-reply@redmine.org>" do
      assert_match /\Aredmine.issue-\d+\.\d+\.3@redmine.org\z/,
                   Mailer.token_for(Issue.generate!, User.find(3))
    end
  end

  def test_layout_should_include_the_emails_header
    with_settings :emails_header => '*Header content*', :text_formatting => 'textile' do
      with_settings :plain_text_mail => 0 do
        assert Mailer.test_email(User.find(1)).deliver_now
        assert_select_email do
          assert_select ".header" do
            assert_select "strong", :text => "Header content"
          end
        end
      end
      with_settings :plain_text_mail => 1 do
        assert Mailer.test_email(User.find(1)).deliver_now
        mail = last_email
        assert_include "*Header content*", mail.body.decoded
      end
    end
  end

  def test_layout_should_not_include_empty_emails_header
    with_settings :emails_header => "", :plain_text_mail => 0 do
      assert Mailer.test_email(User.find(1)).deliver_now
      assert_select_email do
        assert_select ".header", false
      end
    end
  end

  def test_layout_should_include_the_emails_footer
    with_settings :emails_footer => '*Footer content*', :text_formatting => 'textile' do
      with_settings :plain_text_mail => 0 do
        assert Mailer.test_email(User.find(1)).deliver_now
        assert_select_email do
          assert_select ".footer" do
            assert_select "strong", :text => "Footer content"
          end
        end
      end
      with_settings :plain_text_mail => 1 do
        assert Mailer.test_email(User.find(1)).deliver_now
        mail = last_email
        assert_include "\n-- \n", mail.body.decoded
        assert_include "*Footer content*", mail.body.decoded
      end
    end
  end

  def test_layout_should_not_include_empty_emails_footer
    with_settings :emails_footer => "" do
      with_settings :plain_text_mail => 0 do
        assert Mailer.test_email(User.find(1)).deliver_now
        assert_select_email do
          assert_select ".footer", false
        end
      end
      with_settings :plain_text_mail => 1 do
        assert Mailer.test_email(User.find(1)).deliver_now
        mail = last_email
        assert_not_include "\n-- \n", mail.body.decoded
      end
    end
  end

  def test_should_escape_html_templates_only
    Issue.generate!(:project_id => 1, :tracker_id => 1, :subject => 'Subject with a <tag>', :notify => true)
    mail = last_email
    assert_equal 2, mail.parts.size
    assert_include '<tag>', text_part.body.encoded
    assert_include '&lt;tag&gt;', html_part.body.encoded
  end

  def test_should_raise_delivery_errors_when_raise_delivery_errors_is_true
    mail = Mailer.test_email(User.find(1))
    mail.delivery_method.stubs(:deliver!).raises(StandardError.new("delivery error"))

    ActionMailer::Base.raise_delivery_errors = true
    assert_raise StandardError, "delivery error" do
      mail.deliver
    end
  ensure
    ActionMailer::Base.raise_delivery_errors = false
  end

  def test_should_log_delivery_errors_when_raise_delivery_errors_is_false
    mail = Mailer.test_email(User.find(1))
    mail.delivery_method.stubs(:deliver!).raises(StandardError.new("delivery error"))

    Rails.logger.expects(:error).with("Email delivery error: delivery error")
    ActionMailer::Base.raise_delivery_errors = false
    assert_nothing_raised do
      mail.deliver
    end
  end

  def test_with_synched_deliveries_should_yield_with_synced_deliveries
    ActionMailer::MailDeliveryJob.queue_adapter = ActiveJob::QueueAdapters::AsyncAdapter.new

    Mailer.with_synched_deliveries do
      assert_kind_of ActiveJob::QueueAdapters::InlineAdapter, ActionMailer::MailDeliveryJob.queue_adapter
    end
    assert_kind_of ActiveJob::QueueAdapters::AsyncAdapter, ActionMailer::MailDeliveryJob.queue_adapter
  ensure
    ActionMailer::MailDeliveryJob.queue_adapter = ActiveJob::QueueAdapters::InlineAdapter.new
  end

  def test_email_addresses_should_keep_addresses
    assert_equal ["foo@example.net"],
                 Mailer.email_addresses("foo@example.net")
    assert_equal ["foo@example.net", "bar@example.net"],
                 Mailer.email_addresses(["foo@example.net", "bar@example.net"])
  end

  def test_email_addresses_should_replace_users_with_their_email_addresses
    assert_equal ["admin@somenet.foo"],
                 Mailer.email_addresses(User.find(1))
    assert_equal ["admin@somenet.foo", "jsmith@somenet.foo"],
                 Mailer.email_addresses(User.where(:id => [1, 2])).sort
  end

  def test_email_addresses_should_include_notified_emails_addresses_only
    EmailAddress.create!(:user_id => 2, :address => "another@somenet.foo", :notify => false)
    EmailAddress.create!(:user_id => 2, :address => "another2@somenet.foo")
    assert_equal ["another2@somenet.foo", "jsmith@somenet.foo"],
                 Mailer.email_addresses(User.find(2)).sort
  end

  private

  # Returns an array of email addresses to which emails were sent
  def recipients
    ActionMailer::Base.deliveries.map(&:to).flatten.sort
  end

  def last_email
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    mail
  end

  def text_part
    last_email.parts.detect {|part| part.content_type.include?('text/plain')}
  end

  def html_part
    last_email.parts.detect {|part| part.content_type.include?('text/html')}
  end

  def destination_user(mail)
    EmailAddress.where(:address => [mail.to, mail.cc].flatten).map(&:user).first
  end
end
