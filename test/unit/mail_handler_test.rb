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

class MailHandlerTest < ActiveSupport::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures/mail_handler'

  def setup
    ActionMailer::Base.deliveries.clear
    Setting.notified_events = Redmine::Notifiable.all.collect(&:name)
    User.current = nil
  end

  def teardown
    Setting.clear_cache
  end

  def test_add_issue_with_specific_overrides
    issue =
      submit_email(
        'ticket_on_given_project.eml',
        :allow_override =>
          ['status', 'start_date', 'due_date', 'assigned_to',
           'fixed_version', 'estimated_hours', 'done_ratio',
           'parent_issue']
      )
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    issue.reload
    assert_equal Project.find(2), issue.project
    assert_equal issue.project.trackers.first, issue.tracker
    assert_equal 'New ticket on a given project', issue.subject
    assert_equal User.find_by_login('jsmith'), issue.author
    assert_equal IssueStatus.find_by_name('Resolved'), issue.status
    assert issue.description.include?('Lorem ipsum dolor sit amet, consectetuer adipiscing elit.')
    assert_equal '2010-01-01', issue.start_date.to_s
    assert_equal '2010-12-31', issue.due_date.to_s
    assert_equal User.find_by_login('jsmith'), issue.assigned_to
    assert_equal Version.find_by_name('Alpha'), issue.fixed_version
    assert_equal 2.5, issue.estimated_hours
    assert_equal 30, issue.done_ratio
    assert_equal Issue.find(4), issue.parent
    # keywords should be removed from the email body
    assert !issue.description.match(/^Project:/i)
    assert !issue.description.match(/^Status:/i)
    assert !issue.description.match(/^Start Date:/i)
  end

  def test_add_issue_with_all_overrides
    issue = submit_email('ticket_on_given_project.eml', :allow_override => 'all')
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    issue.reload
    assert_equal Project.find(2), issue.project
    assert_equal issue.project.trackers.first, issue.tracker
    assert_equal IssueStatus.find_by_name('Resolved'), issue.status
    assert issue.description.include?('Lorem ipsum dolor sit amet, consectetuer adipiscing elit.')
    assert_equal '2010-01-01', issue.start_date.to_s
    assert_equal '2010-12-31', issue.due_date.to_s
    assert_equal User.find_by_login('jsmith'), issue.assigned_to
    assert_equal Version.find_by_name('Alpha'), issue.fixed_version
    assert_equal 2.5, issue.estimated_hours
    assert_equal 30, issue.done_ratio
    assert_equal Issue.find(4), issue.parent
  end

  def test_add_issue_without_overrides_should_ignore_attributes
    WorkflowRule.delete_all
    issue = submit_email('ticket_on_given_project.eml')
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    issue.reload
    assert_equal Project.find(2), issue.project
    assert_equal 'New ticket on a given project', issue.subject
    assert issue.description.include?('Lorem ipsum dolor sit amet, consectetuer adipiscing elit.')
    assert_equal User.find_by_login('jsmith'), issue.author

    assert_equal issue.project.trackers.first, issue.tracker
    assert_equal 'New', issue.status.name
    assert_not_equal '2010-01-01', issue.start_date.to_s
    assert_nil issue.due_date
    assert_nil issue.assigned_to
    assert_nil issue.fixed_version
    assert_nil issue.estimated_hours
    assert_equal 0, issue.done_ratio
    assert_nil issue.parent
  end

  def test_add_issue_to_project_specified_by_subaddress
    # This email has redmine+onlinestore@somenet.foo as 'To' header
    issue =
      submit_email(
        'ticket_on_project_given_by_to_header.eml',
        :issue => {:tracker => 'Support request'},
        :project_from_subaddress => 'redmine@somenet.foo'
      )
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    issue.reload
    assert_equal 'onlinestore', issue.project.identifier
    assert_equal 'Support request', issue.tracker.name
  end

  def test_add_issue_with_default_tracker
    # This email contains: 'Project: onlinestore'
    issue =
      submit_email(
        'ticket_on_given_project.eml',
        :issue => {:tracker => 'Support request'}
      )
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    issue.reload
    assert_equal 'Support request', issue.tracker.name
  end

  def test_add_issue_with_default_version
    # This email contains: 'Project: onlinestore'
    issue =
      submit_email(
        'ticket_on_given_project.eml',
        :issue => {:fixed_version => 'Alpha'}
      )
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    assert_equal 'Alpha', issue.reload.fixed_version.name
  end

  def test_add_issue_with_default_assigned_to
    # This email contains: 'Project: onlinestore'
    issue =
      submit_email(
        'ticket_on_given_project.eml',
        :issue => {:assigned_to => 'jsmith'}
      )
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    assert_equal 'jsmith', issue.reload.assigned_to.login
  end

  def test_add_issue_with_status_override
    # This email contains: 'Project: onlinestore' and 'Status: Resolved'
    issue = submit_email('ticket_on_given_project.eml', :allow_override => ['status'])
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    issue.reload
    assert_equal Project.find(2), issue.project
    assert_equal IssueStatus.find_by_name("Resolved"), issue.status
  end

  def test_add_issue_should_accept_is_private_attribute
    issue = submit_email('ticket_on_given_project.eml', :issue => {:is_private => '1'})
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    assert_equal true, issue.reload.is_private
  end

  def test_add_issue_with_group_assignment
    with_settings :issue_group_assignment => '1' do
      issue = submit_email('ticket_on_given_project.eml', :allow_override => ['assigned_to']) do |email|
        email.gsub!('Assigned to: John Smith', 'Assigned to: B Team')
      end
      assert issue.is_a?(Issue)
      assert !issue.new_record?
      issue.reload
      assert_equal Group.find(11), issue.assigned_to
    end
  end

  def test_add_issue_with_partial_attributes_override
    issue =
      submit_email(
        'ticket_with_attributes.eml',
        :issue => {:priority => 'High'},
        :allow_override => ['tracker']
      )
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    issue.reload
    assert_equal 'New ticket on a given project', issue.subject
    assert_equal User.find_by_login('jsmith'), issue.author
    assert_equal Project.find(2), issue.project
    assert_equal 'Feature request', issue.tracker.to_s
    assert_nil issue.category
    assert_equal 'High', issue.priority.to_s
    assert issue.description.include?('Lorem ipsum dolor sit amet, consectetuer adipiscing elit.')
  end

  def test_add_issue_with_spaces_between_attribute_and_separator
    issue =
      submit_email(
        'ticket_with_spaces_between_attribute_and_separator.eml',
        :allow_override => 'tracker,category,priority'
      )
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    issue.reload
    assert_equal 'New ticket on a given project', issue.subject
    assert_equal User.find_by_login('jsmith'), issue.author
    assert_equal Project.find(2), issue.project
    assert_equal 'Feature request', issue.tracker.to_s
    assert_equal 'Stock management', issue.category.to_s
    assert_equal 'Urgent', issue.priority.to_s
    assert issue.description.include?('Lorem ipsum dolor sit amet, consectetuer adipiscing elit.')
  end

  def test_add_issue_with_attachment_to_specific_project
    issue = submit_email('ticket_with_attachment.eml', :issue => {:project => 'onlinestore'})
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    issue.reload
    assert_equal 'Ticket created by email with attachment', issue.subject
    assert_equal User.find_by_login('jsmith'), issue.author
    assert_equal Project.find(2), issue.project
    assert_equal 'This is  a new ticket with attachments', issue.description
    # Attachment properties
    assert_equal 1, issue.attachments.size
    assert_equal 'Paella.jpg', issue.attachments.first.filename
    assert_equal 'image/jpeg', issue.attachments.first.content_type
    assert_equal 10790, issue.attachments.first.filesize
  end

  def test_add_issue_with_custom_fields
    mutiple = IssueCustomField.generate!(:field_format => 'list',
                                         :name => 'OS', :multiple => true,
                                         :possible_values => ['Linux', 'Windows', 'Mac OS X'])

    issue =
      submit_email(
        'ticket_with_custom_fields.eml',
        :issue => {:project => 'onlinestore'},
        :allow_override => ['database', 'Searchable_field', 'OS']
      )
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    issue.reload
    assert_equal 'New ticket with custom field values', issue.subject
    assert_equal 'PostgreSQL', issue.custom_field_value(1)
    assert_equal 'Value for a custom field', issue.custom_field_value(2)
    assert_equal ['Mac OS X', 'Windows'], issue.custom_field_value(mutiple.id).sort
    assert !issue.description.match(/^searchable field:/i)
  end

  def test_add_issue_with_version_custom_fields
    field = IssueCustomField.create!(:name => 'Affected version',
                                     :field_format => 'version',
                                     :is_for_all => true,
                                     :tracker_ids => [1, 2, 3])
    issue =
      submit_email(
        'ticket_with_custom_fields.eml',
        :issue => {:project => 'ecookbook'},
        :allow_override => ['affected version']
      ) do |email|
        email << "Affected version: 1.0\n"
      end
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    issue.reload
    assert_equal '2', issue.custom_field_value(field)
  end

  def test_add_issue_should_match_assignee_on_display_name
    user = User.generate!(:firstname => 'Foo Bar', :lastname => 'Foo Baz')
    User.add_to_project(user, Project.find(2))
    issue = submit_email('ticket_on_given_project.eml', :allow_override => ['assigned_to']) do |email|
      email.sub!(/^Assigned to.*$/, 'Assigned to: Foo Bar Foo baz')
    end
    assert issue.is_a?(Issue)
    assert_equal user, issue.assigned_to
  end

  def test_add_issue_should_set_default_start_date
    with_settings :default_issue_start_date_to_creation_date => '1' do
      issue = submit_email('ticket_with_cc.eml', :issue => {:project => 'ecookbook'})
      assert issue.is_a?(Issue)
      assert_equal Date.today, issue.start_date
    end
  end

  def test_add_issue_should_add_cc_as_watchers
    user = User.find_by_mail('dlopper@somenet.foo')
    issue = submit_email('ticket_with_cc.eml', :issue => {:project => 'ecookbook'})
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    assert issue.watched_by?(user)
    assert_equal 1, issue.watcher_user_ids.size
    assert_include user, issue.watcher_users.to_a
  end

  def test_add_issue_from_additional_email_address
    user = User.find(2)
    user.mail = 'mainaddress@somenet.foo'
    user.save!
    EmailAddress.create!(:user => user, :address => 'jsmith@somenet.foo')

    issue = submit_email('ticket_on_given_project.eml')
    assert issue
    assert_equal user, issue.author
  end

  def test_add_issue_by_unknown_user
    assert_no_difference 'User.count' do
      assert_equal(
        false,
        submit_email(
          'ticket_by_unknown_user.eml',
          :issue => {:project => 'ecookbook'}
        )
      )
    end
  end

  def test_add_issue_by_anonymous_user
    Role.anonymous.add_permission!(:add_issues)
    Role.anonymous.add_permission!(:add_issue_watchers)
    assert_no_difference 'User.count' do
      issue =
        submit_email(
          'ticket_by_unknown_user.eml',
          :issue => {:project => 'ecookbook'},
          :unknown_user => 'accept'
        )
      assert issue.is_a?(Issue)
      assert issue.author.anonymous?
      issue.reload
      assert issue.watched_by?(User.find_by_mail('dlopper@somenet.foo'))
      assert_equal 1, issue.watchers.size
    end
  end

  def test_add_issue_by_anonymous_user_with_no_from_address
    Role.anonymous.add_permission!(:add_issues)
    assert_no_difference 'User.count' do
      issue =
        submit_email(
          'ticket_by_empty_user.eml',
          :issue => {:project => 'ecookbook'},
          :unknown_user => 'accept'
        )
      assert issue.is_a?(Issue)
      assert issue.author.anonymous?
    end
  end

  def test_add_issue_by_anonymous_user_on_private_project
    Role.anonymous.add_permission!(:add_issues)
    assert_no_difference 'User.count' do
      assert_no_difference 'Issue.count' do
        assert_equal(
          false,
          submit_email(
            'ticket_by_unknown_user.eml',
            :issue => {:project => 'onlinestore'},
            :unknown_user => 'accept'
          )
        )
      end
    end
  end

  def test_add_issue_by_anonymous_user_on_private_project_without_permission_check
    assert_no_difference 'User.count' do
      assert_difference 'Issue.count' do
        issue =
          submit_email(
            'ticket_by_unknown_user.eml',
            :issue => {:project => 'onlinestore'},
            :no_permission_check => '1',
            :unknown_user => 'accept'
          )
        assert issue.is_a?(Issue)
        assert issue.author.anonymous?
        assert !issue.project.is_public?
      end
    end
  end

  def test_no_issue_on_closed_project_without_permission_check
    Project.find(2).close
    assert_no_difference 'User.count' do
      assert_no_difference 'Issue.count' do
        submit_email(
          'ticket_by_unknown_user.eml',
          :issue => {:project => 'onlinestore'},
          :no_permission_check => '1',
          :unknown_user => 'accept'
        )
      end
    end
  ensure
    Project.find(2).reopen
  end

  def test_no_issue_on_closed_project_without_issue_tracking_module
    assert_no_difference 'User.count' do
      assert_no_difference 'Issue.count' do
        submit_email(
          'ticket_by_unknown_user.eml',
          :issue => {:project => 'subproject2'},
          :no_permission_check => '1',
          :unknown_user => 'accept'
        )
      end
    end
  end

  def test_add_issue_by_created_user
    Setting.default_language = 'en'
    assert_difference 'User.count' do
      issue =
        submit_email(
          'ticket_by_unknown_user.eml',
          :issue => {:project => 'ecookbook'},
          :unknown_user => 'create'
        )
      assert issue.is_a?(Issue)
      assert issue.author.active?
      assert_equal 'john.doe@somenet.foo', issue.author.mail
      assert_equal 'John', issue.author.firstname
      assert_equal 'Doe', issue.author.lastname

      # account information
      email = ActionMailer::Base.deliveries.first
      assert_not_nil email
      assert email.subject.include?('account activation')
      login = mail_body(email).match(/\* Login: (.*)$/)[1].strip
      password = mail_body(email).match(/\* Password: (.*)$/)[1].strip
      assert_equal issue.author, User.try_to_login(login, password)
    end
  end

  def test_add_issue_should_send_notification
    issue = submit_email('ticket_on_given_project.eml', :allow_override => 'all')
    assert issue.is_a?(Issue)
    assert !issue.new_record?

    assert_equal 4, issue.parent_issue_id
    assert_equal 2, ActionMailer::Base.deliveries.size

    [
      [issue.id, 'New ticket on a given project'],
      [4, 'Issue on project 2'],
    ].each do |issue_id, issue_subject|
      mail =
        ActionMailer::Base.deliveries.detect do |m|
          /##{issue_id}/.match?(m.subject) && /#{issue_subject}/.match?(m.subject)
        end
      assert_not_nil mail
    end
  end

  def test_created_user_should_be_added_to_groups
    group1 = Group.generate!
    group2 = Group.generate!

    assert_difference 'User.count' do
      submit_email(
        'ticket_by_unknown_user.eml',
        :issue => {:project => 'ecookbook'},
        :unknown_user => 'create',
        :default_group => "#{group1.name},#{group2.name}"
      )
    end
    user = User.order('id DESC').first
    assert_equal [group1, group2].sort, user.groups.sort
  end

  def test_created_user_should_not_receive_account_information_with_no_account_info_option
    assert_difference 'User.count' do
      submit_email(
        'ticket_by_unknown_user.eml',
        :issue => {:project => 'ecookbook'},
        :unknown_user => 'create',
        :no_account_notice => '1'
      )
    end

    # only 2 emails for the new issue notification
    assert_equal 2, ActionMailer::Base.deliveries.size
    ActionMailer::Base.deliveries.each do |email|
      assert_include 'Ticket by unknown user', email.subject
    end
  end

  def test_created_user_should_have_mail_notification_to_none_with_no_notification_option
    assert_difference 'User.count' do
      submit_email(
        'ticket_by_unknown_user.eml',
        :issue => {:project => 'ecookbook'},
        :unknown_user => 'create',
        :no_notification => '1'
      )
    end
    user = User.order('id DESC').first
    assert_equal 'none', user.mail_notification
  end

  def test_add_issue_without_from_header
    Role.anonymous.add_permission!(:add_issues)
    assert_equal false, submit_email('ticket_without_from_header.eml')
  end

  def test_add_issue_with_invalid_attributes
    with_settings :default_issue_start_date_to_creation_date => '0' do
      issue =
        submit_email(
          'ticket_with_invalid_attributes.eml',
          :allow_override => 'tracker,category,priority'
        )
      assert issue.is_a?(Issue)
      assert !issue.new_record?
      issue.reload
      assert_nil issue.assigned_to
      assert_nil issue.start_date
      assert_nil issue.due_date
      assert_equal 0, issue.done_ratio
      assert_nil issue.parent
      assert_equal 'Normal', issue.priority.to_s
      assert issue.description.include?('Lorem ipsum dolor sit amet, consectetuer adipiscing elit.')
    end
  end

  def test_add_issue_with_invalid_project_should_be_assigned_to_default_project
    issue =
      submit_email(
        'ticket_on_given_project.eml',
        :issue => {:project => 'ecookbook'},
        :allow_override => 'project'
      ) do |email|
        email.gsub!(/^Project:.+$/, 'Project: invalid')
      end
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    assert_equal 'ecookbook', issue.project.identifier
  end

  def test_add_issue_with_private_keyword
    User.find_by_mail('jsmith@somenet.foo').update_attribute 'language', 'fr'
    # give the user permission to set issues private:
    MemberRole.create! member_id: 3, role_id: 1
    issue =
      submit_email(
        'ticket_with_localized_private_flag.eml',
        :allow_override => 'is_private,tracker,category,priority'
      )
    assert issue.is_a?(Issue)
    assert_not issue.new_record?
    issue.reload
    assert_equal 'New ticket on a given project', issue.subject
    assert issue.is_private
  end

  def test_add_issue_with_localized_attributes
    User.find_by_mail('jsmith@somenet.foo').update_attribute 'language', 'fr'
    issue =
      submit_email(
        'ticket_with_localized_attributes.eml',
        :allow_override => 'tracker,category,priority'
      )
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    issue.reload
    assert_equal 'New ticket on a given project', issue.subject
    assert_equal User.find_by_login('jsmith'), issue.author
    assert_equal Project.find(2), issue.project
    assert_equal 'Feature request', issue.tracker.to_s
    assert_equal 'Stock management', issue.category.to_s
    assert_equal 'Urgent', issue.priority.to_s
    assert issue.description.include?('Lorem ipsum dolor sit amet, consectetuer adipiscing elit.')
  end

  def test_add_issue_with_japanese_keywords
    tracker = Tracker.generate!(:name => '開発')
    Project.find(1).trackers << tracker
    issue =
      submit_email(
        'japanese_keywords_iso_2022_jp.eml',
        :issue => {:project => 'ecookbook'},
        :allow_override => 'tracker'
      )
    assert_kind_of Issue, issue
    assert_equal tracker, issue.tracker
  end

  def test_add_issue_from_apple_mail
    set_tmp_attachments_directory
    issue =
      submit_email(
        'apple_mail_with_attachment.eml',
        :issue => {:project => 'ecookbook'}
      )
    assert_kind_of Issue, issue
    assert_equal 1, issue.attachments.size

    attachment = issue.attachments.first
    assert_equal 'paella.jpg', attachment.filename
    assert_equal 10790, attachment.filesize
    assert File.exist?(attachment.diskfile)
    assert_equal 10790, File.size(attachment.diskfile)
    assert_equal '4474dd534c36bdd212e2efc549507377c3e77147c9167b66dedcebfe9da8807f', attachment.digest
  end

  def test_thunderbird_with_attachment_ja
    set_tmp_attachments_directory
    issue =
      submit_email(
        'thunderbird_with_attachment_ja.eml',
        :issue => {:project => 'ecookbook'}
      )
    assert_kind_of Issue, issue
    assert_equal 1, issue.attachments.size
    attachment = issue.attachments.first
    assert_equal 'テスト.txt', attachment.filename
    assert_equal 5, attachment.filesize
    assert File.exist?(attachment.diskfile)
    assert_equal 5, File.size(attachment.diskfile)
    assert_equal 'f2ca1bb6c7e907d06dafe4687e579fce76b37e4e93b7605022da52e6ccc26fd2', attachment.digest
  end

  def test_invalid_utf8
    issue =
      submit_email(
        'invalid_utf8.eml',
        :issue => {:project => 'ecookbook'}
      )
    assert_kind_of Issue, issue
    assert_equal 'Здравствуйте?', issue.description
  end

  def test_gmail_with_attachment_ja
    set_tmp_attachments_directory
    issue =
      submit_email(
        'gmail_with_attachment_ja.eml',
        :issue => {:project => 'ecookbook'}
      )
    assert_kind_of Issue, issue
    assert_equal 1, issue.attachments.size
    attachment = issue.attachments.first
    assert_equal 'テスト.txt', attachment.filename
    assert_equal 5, attachment.filesize
    assert File.exist?(attachment.diskfile)
    assert_equal 5, File.size(attachment.diskfile)
    assert_equal 'f2ca1bb6c7e907d06dafe4687e579fce76b37e4e93b7605022da52e6ccc26fd2', attachment.digest
  end

  def test_thunderbird_with_attachment_latin1
    set_tmp_attachments_directory
    issue =
      submit_email(
        'thunderbird_with_attachment_iso-8859-1.eml',
        :issue => {:project => 'ecookbook'}
      )
    assert_kind_of Issue, issue
    assert_equal 1, issue.attachments.size
    u = +''
    u1 = 'ÄäÖöÜü'
    11.times {u << u1}
    attachment = issue.attachments.first
    assert_equal "#{u}.png", attachment.filename
    assert_equal 130, attachment.filesize
    assert File.exist?(attachment.diskfile)
    assert_equal 130, File.size(attachment.diskfile)
    assert_equal '5635d67364de20432247e651dfe86fcb2265ad5e9750bd8bba7319a86363e738', attachment.digest
  end

  def test_gmail_with_attachment_latin1
    set_tmp_attachments_directory
    issue =
      submit_email(
        'gmail_with_attachment_iso-8859-1.eml',
        :issue => {:project => 'ecookbook'}
      )
    assert_kind_of Issue, issue
    assert_equal 1, issue.attachments.size
    u = +''
    u1 = 'ÄäÖöÜü'
    11.times {u << u1}
    attachment = issue.attachments.first
    assert_equal "#{u}.txt", attachment.filename
    assert_equal 5, attachment.filesize
    assert File.exist?(attachment.diskfile)
    assert_equal 5, File.size(attachment.diskfile)
    assert_equal 'f2ca1bb6c7e907d06dafe4687e579fce76b37e4e93b7605022da52e6ccc26fd2', attachment.digest
  end

  def test_mail_with_attachment_latin2
    set_tmp_attachments_directory
    issue =
      submit_email(
        'ticket_with_text_attachment_iso-8859-2.eml',
        :issue => {:project => 'ecookbook'}
      )
    assert_kind_of Issue, issue
    assert_equal 1, issue.attachments.size
    attachment = issue.attachments.first
    assert_equal 'latin2.txt', attachment.filename
    assert_equal 19, attachment.filesize
    assert File.exist?(attachment.diskfile)
    assert_equal 19, File.size(attachment.diskfile)
    content = (+"p\xF8\xEDli\xB9 \xBEluou\xE8k\xFD k\xF9n").force_encoding('CP852')
    assert_equal content, File.read(attachment.diskfile).force_encoding('CP852')
  end

  def test_empty_attachment_should_not_be_imported
    issue =
      submit_email(
        'ticket_with_empty_attachment.eml',
        :issue => {:project => 'ecookbook'}
      )
    assert_equal 0, issue.attachments.size
  end

  def test_multiple_inline_text_parts_should_be_appended_to_issue_description
    issue = submit_email('multiple_text_parts.eml', :issue => {:project => 'ecookbook'})
    assert_include 'first', issue.description
    assert_include 'second', issue.description
    assert_include 'third', issue.description
  end

  def test_empty_text_part_should_not_stop_looking_for_content
    issue = submit_email('empty_text_part.eml', :issue => {:project => 'ecookbook'})
    assert_equal 'The html part.', issue.description
  end

  def test_empty_text_and_html_part_should_make_an_empty_description
    issue = submit_email('empty_text_and_html_part.eml', :issue => {:project => 'ecookbook'})
    assert_equal '', issue.description
  end

  def test_preferred_body_part_setting
    with_settings :mail_handler_preferred_body_part => 'plain' do
      issue = submit_email('different_contents_in_text_and_html.eml', :issue => {:project => 'ecookbook'})
      assert_equal 'The text part.', issue.description
    end
    with_settings :mail_handler_preferred_body_part => 'html' do
      issue = submit_email('different_contents_in_text_and_html.eml', :issue => {:project => 'ecookbook'})
      assert_equal 'The html part.', issue.description
    end
  end

  def test_attachment_text_part_should_be_added_as_issue_attachment
    issue = submit_email('multiple_text_parts.eml', :issue => {:project => 'ecookbook'})
    assert_not_include 'Plain text attachment', issue.description
    attachment = issue.attachments.detect {|a| a.filename == 'textfile.txt'}
    assert_not_nil attachment
    assert_include 'Plain text attachment', File.read(attachment.diskfile)
  end

  def test_add_issue_with_iso_8859_1_subject
    issue =
      submit_email(
        'subject_as_iso-8859-1.eml',
        :issue => {:project => 'ecookbook'}
      )
    assert_kind_of Issue, issue
    assert_equal 'Testmail from Webmail: ä ö ü...', issue.subject
  end

  def test_quoted_printable_utf8
    issue =
      submit_email(
        'quoted_printable_utf8.eml',
        :issue => {:project => 'ecookbook'}
      )
    assert_kind_of Issue, issue
    assert_equal 'Freundliche Grüsse', issue.description
  end

  def test_gmail_iso8859_2
    issue =
      submit_email(
        'gmail-iso8859-2.eml',
        :issue => {:project => 'ecookbook'}
      )
    assert_kind_of Issue, issue
    assert issue.description.include?('Na štriku se suši šosić.')
  end

  def test_add_issue_with_japanese_subject
    issue =
      submit_email(
        'subject_japanese_1.eml',
        :issue => {:project => 'ecookbook'}
      )
    assert_kind_of Issue, issue
    assert_equal 'テスト', issue.subject
  end

  def test_add_issue_with_korean_body
    issue =
      submit_email(
        'body_ks_c_5601-1987.eml',
        :issue => {:project => 'ecookbook'}
      )
    assert_kind_of Issue, issue
    assert_equal '고맙습니다.', issue.description
  end

  def test_add_issue_with_no_subject_header
    with_settings :default_language => 'en' do
      issue =
        submit_email(
          'no_subject_header.eml',
          :issue => {:project => 'ecookbook'}
        )
      assert_kind_of Issue, issue
      assert_equal "(no subject)", issue.subject
    end
  end

  def test_add_issue_with_mixed_japanese_subject
    issue =
      submit_email(
        'subject_japanese_2.eml',
        :issue => {:project => 'ecookbook'}
      )
    assert_kind_of Issue, issue
    assert_equal 'Re: テスト', issue.subject
  end

  def test_add_issue_with_iso_2022_jp_ms_subject
    # CIRCLED DIGIT ONE character is undefined in ISO-2022-JP but
    # defined in some vendor-extended variants such as ISO-2022-JP-MS.
    # This test makes sure that mail gem replaces an undefined characters
    # with a replacement character instead of breaking the whole subject.
    issue =
      submit_email(
        'subject_japanese_3.eml',
        :issue => {:project => 'ecookbook'}
      )
    assert_kind_of Issue, issue
    assert_match /丸数字テスト/, issue.subject
  end

  def test_should_ignore_emails_from_locked_users
    User.find(2).lock!

    MailHandler.any_instance.expects(:dispatch).never
    assert_no_difference 'Issue.count' do
      assert_equal false, submit_email('ticket_on_given_project.eml')
    end
  end

  def test_should_ignore_emails_from_emission_address
    emission_addresses = [
      'redmine@example.net',
      'Redmine <redmine@example.net>',
      'redmine@example.net (Redmine)'
    ]
    Role.anonymous.add_permission!(:add_issues)
    emission_addresses.each do |addr|
      with_settings :mail_from => addr do
        assert_no_difference 'User.count' do
          assert_equal(
            false,
            submit_email(
              'ticket_from_emission_address.eml',
              :issue => {:project => 'ecookbook'},
              :unknown_user => 'create'
            )
          )
        end
      end
    end
  end

  def test_should_ignore_auto_replied_emails
    MailHandler.any_instance.expects(:dispatch).never
    [
      "Auto-Submitted: auto-replied",
      "Auto-Submitted: Auto-Replied",
      "Auto-Submitted: auto-generated",
      'X-Autoreply: yes'
    ].each do |header|
      raw = IO.read(File.join(FIXTURES_PATH, 'ticket_on_given_project.eml'))
      raw = header + "\n" + raw

      assert_no_difference 'Issue.count' do
        assert_equal false, MailHandler.receive(raw), "email with #{header} header was not ignored"
      end
    end
  end

  test "should not ignore Auto-Submitted headers not defined in RFC3834" do
    [
      "Auto-Submitted: auto-forwarded"
    ].each do |header|
      raw = IO.read(File.join(FIXTURES_PATH, 'ticket_on_given_project.eml'))
      raw = header + "\n" + raw

      assert_difference 'Issue.count', 1 do
        assert_not_nil MailHandler.receive(raw), "email with #{header} header was ignored"
      end
    end
  end

  def test_add_issue_should_send_email_notification
    Setting.notified_events = ['issue_added']
    # This email contains: 'Project: onlinestore'
    issue = submit_email('ticket_on_given_project.eml')
    assert issue.is_a?(Issue)
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  def test_update_issue
    journal = submit_email('ticket_reply.eml')
    assert journal.is_a?(Journal)
    assert_equal User.find_by_login('jsmith'), journal.user
    assert_equal Issue.find(2), journal.journalized
    assert_match /This is reply/, journal.notes
    assert_equal false, journal.private_notes
    assert_equal 'Feature request', journal.issue.tracker.name
  end

  def test_update_issue_should_accept_issue_id_after_space_inside_brackets
    journal = submit_email('ticket_reply_with_status.eml') do |email|
      assert email.sub!(/^Subject:.*$/, "Subject: Re: [Feature request #2] Add ingredients categories")
    end
    assert journal.is_a?(Journal)
    assert_equal Issue.find(2), journal.journalized
  end

  def test_update_issue_should_accept_issue_id_inside_brackets
    journal = submit_email('ticket_reply_with_status.eml') do |email|
      assert email.sub!(/^Subject:.*$/, "Subject: Re: [#2] Add ingredients categories")
    end
    assert journal.is_a?(Journal)
    assert_equal Issue.find(2), journal.journalized
  end

  def test_update_issue_should_ignore_bogus_issue_ids_in_subject
    journal = submit_email('ticket_reply_with_status.eml') do |email|
      assert email.sub!(/^Subject:.*$/, "Subject: Re: [12345#1][bogus#1][Feature request #2] Add ingredients categories")
    end
    assert journal.is_a?(Journal)
    assert_equal Issue.find(2), journal.journalized
  end

  def test_update_issue_with_attribute_changes
    journal = submit_email('ticket_reply_with_status.eml',
                           :allow_override => ['status', 'assigned_to',
                                               'start_date', 'due_date',
                                               'float field'])
    assert journal.is_a?(Journal)
    issue = Issue.find(journal.issue.id)
    assert_equal User.find_by_login('jsmith'), journal.user
    assert_equal Issue.find(2), journal.journalized
    assert_match /This is reply/, journal.notes
    assert_equal 'Feature request', journal.issue.tracker.name
    assert_equal IssueStatus.find_by_name("Resolved"), issue.status
    assert_equal '2010-01-01', issue.start_date.to_s
    assert_equal '2010-12-31', issue.due_date.to_s
    assert_equal User.find_by_login('jsmith'), issue.assigned_to
    assert_equal "52.6", issue.custom_value_for(CustomField.find_by_name('Float field')).value
    # keywords should be removed from the email body
    assert !journal.notes.match(/^Status:/i)
    assert !journal.notes.match(/^Start Date:/i)
  end

  def test_update_issue_with_attachment
    assert_difference 'Journal.count' do
      assert_difference 'JournalDetail.count' do
        assert_difference 'Attachment.count' do
          assert_no_difference 'Issue.count' do
            journal = submit_email('ticket_with_attachment.eml') do |raw|
              raw.gsub! /^Subject: .*$/, 'Subject: Re: [Cookbook - Feature #2] (New) Add ingredients categories'
            end
          end
        end
      end
    end
    journal = Journal.order('id DESC').first
    assert_equal Issue.find(2), journal.journalized
    assert_equal 1, journal.details.size

    detail = journal.details.first
    assert_equal 'attachment', detail.property
    assert_equal 'Paella.jpg', detail.value
  end

  def test_update_issue_should_discard_all_changes_on_validation_failure
    Issue.any_instance.stubs(:valid?).returns(false)
    assert_no_difference 'Journal.count' do
      assert_no_difference 'JournalDetail.count' do
        assert_no_difference 'Attachment.count' do
          assert_no_difference 'Issue.count' do
            journal = submit_email('ticket_with_attachment.eml') do |raw|
              raw.gsub! /^Subject: .*$/, 'Subject: Re: [Cookbook - Feature #2] (New) Add ingredients categories'
            end
          end
        end
      end
    end
  end

  def test_update_issue_should_send_email_notification
    journal = submit_email('ticket_reply.eml')
    assert journal.is_a?(Journal)
    assert_equal 3, ActionMailer::Base.deliveries.size
  end

  def test_update_issue_should_not_set_defaults
    journal =
      submit_email(
        'ticket_reply.eml',
        :issue => {:tracker => 'Support request', :priority => 'High'}
      )
    assert journal.is_a?(Journal)
    assert_match /This is reply/, journal.notes
    assert_equal 'Feature request', journal.issue.tracker.name
    assert_equal 'Normal', journal.issue.priority.name
  end

  def test_update_issue_should_add_cc_as_watchers
    Watcher.delete_all
    issue = Issue.find(2)

    assert_difference 'Watcher.count' do
      assert submit_email('issue_update_with_cc.eml')
    end
    issue.reload
    assert_equal 1, issue.watcher_user_ids.size
    assert issue.watched_by?(User.find_by_mail('dlopper@somenet.foo'))
  end

  def test_update_issue_should_not_add_cc_as_watchers_if_already_watching
    Watcher.delete_all
    issue = Issue.find(2)
    Watcher.create!(:watchable => issue, :user => User.find_by_mail('dlopper@somenet.foo'))

    assert_no_difference 'Watcher.count' do
      assert submit_email('issue_update_with_cc.eml')
    end
  end

  def test_replying_to_a_private_note_should_add_reply_as_private
    private_journal = Journal.create!(:notes => 'Private notes',
                                      :journalized => Issue.find(1),
                                      :private_notes => true, :user_id => 2)

    assert_difference 'Journal.count' do
      journal = submit_email('ticket_reply.eml') do |email|
        email.sub! %r{^In-Reply-To:.*$}, "In-Reply-To: <redmine.journal-#{private_journal.id}.20060719210421@osiris>"
      end

      assert_kind_of Journal, journal
      assert_match /This is reply/, journal.notes
      assert_equal true, journal.private_notes
    end
  end

  def test_reply_to_a_nonexistent_issue
    set_tmp_attachments_directory
    Issue.find(2).destroy
    assert_no_difference 'Issue.count' do
      assert_no_difference 'Journal.count' do
        journal = submit_email('ticket_reply_with_status.eml')
        assert_not journal
      end
    end
  end

  def test_reply_to_an_issue_without_permission
    set_tmp_attachments_directory
    # "add_issue_notes" permission is explicit required to allow users to add notes
    # "edit_issue" permission no longer includes the "add_issue_notes" permission
    Role.all.each {|r| r.remove_permission! :add_issue_notes}
    assert_no_difference 'Issue.count' do
      assert_no_difference 'Journal.count' do
        assert_not submit_email('ticket_reply_with_status.eml')
      end
    end
  end

  def test_reply_to_a_nonexitent_journal
    journal_id = Issue.find(2).journals.last.id
    Journal.destroy(journal_id)
    assert_no_difference 'Issue.count' do
      assert_no_difference 'Journal.count' do
        journal = submit_email('ticket_reply.eml') do |email|
          email.sub! %r{^In-Reply-To:.*$}, "In-Reply-To: <redmine.journal-#{journal_id}.20060719210421@osiris>"
        end
        assert_not journal
      end
    end
  end

  def test_reply_to_a_nonexitent_journal_with_subject_fallback
    journal_id = Issue.find(2).journals.last.id
    Journal.destroy(journal_id)
    assert_no_difference 'Issue.count' do
      assert_difference 'Journal.count', 1 do
        journal = submit_email('ticket_reply.eml') do |email|
          email.sub! %r{^In-Reply-To:.*$}, "In-Reply-To: <redmine.journal-#{journal_id}.20060719210421@osiris>"
          email.sub! %r{^Subject:.*$}, "Subject: Re: [Feature request #2] Add ingredients categories"
        end
        assert_kind_of Journal, journal
        assert_equal Issue.find(2), journal.journalized
      end
    end
  end

  def test_reply_to_a_message
    m = submit_email('message_reply.eml')
    assert m.is_a?(Message)
    assert !m.new_record?
    m.reload
    assert_equal 'Reply via email', m.subject
    # The email replies to message #2 which is part of the thread of message #1
    assert_equal Message.find(1), m.parent
  end

  def test_reply_to_a_message_by_subject
    m = submit_email('message_reply_by_subject.eml')
    assert m.is_a?(Message)
    assert !m.new_record?
    m.reload
    assert_equal 'Reply to the first post', m.subject
    assert_equal Message.find(1), m.parent
  end

  def test_reply_to_a_locked_topic
    # Lock the topic
    topic = Message.find(2).parent
    topic.update_attribute :locked, true

    assert_no_difference('topic.replies_count') do
      m = submit_email('message_reply_by_subject.eml')
      assert_not_kind_of Message, m
    end
  end

  def test_reply_to_a_nonexistent_topic
    Message.find(2).destroy
    assert_no_difference('Message.count') do
      m = submit_email('message_reply_by_subject.eml')
      assert_not m
    end
  end

  def test_reply_to_a_topic_without_permission
    Role.all.each {|r| r.remove_permission! :add_messages}
    assert_no_difference('Message.count') do
      assert_not submit_email('message_reply_by_subject.eml')
    end
  end

  def test_reply_to_a_news
    m = submit_email('news_reply.eml')
    assert m.is_a?(Comment)
    assert !m.new_record?
    m.reload
    assert_equal News.find(1), m.commented
    assert_equal "This is a reply to a news.", m.content
  end

  def test_reply_to_a_news_comment
    m = submit_email('news_comment_reply.eml')
    assert m.is_a?(Comment)
    assert !m.new_record?
    m.reload
    assert_equal News.find(1), m.commented
    assert_equal "This is a reply to a comment.", m.content
  end

  def test_reply_to_a_nonexistant_news
    News.find(1).destroy
    assert_no_difference('Comment.count') do
      assert_not submit_email('news_reply.eml')
      assert_not submit_email('news_comment_reply.eml')
    end
  end

  def test_reply_to_a_news_without_permission
    Role.all.each {|r| r.remove_permission! :comment_news}
    assert_no_difference('Comment.count') do
      assert_not submit_email('news_reply.eml')
      assert_not submit_email('news_comment_reply.eml')
    end
  end

  def test_should_convert_tags_of_html_only_emails
    with_settings :text_formatting => 'textile' do
      issue = submit_email('ticket_html_only.eml', :issue => {:project => 'ecookbook'})
      assert issue.is_a?(Issue)
      assert !issue.new_record?
      issue.reload
      assert_equal 'HTML email', issue.subject
      assert_equal "This is a *html-only* email.\r\n\r\nh1. With a title\r\n\r\nand a paragraph.", issue.description
    end
  end

  def test_should_handle_outlook_web_access_2010_html_only
    issue = submit_email('outlook_web_access_2010_html_only.eml', :issue => {:project => 'ecookbook'})
    assert issue.is_a?(Issue)
    issue.reload
    assert_equal 'Upgrade Redmine to 3.0.x', issue.subject
    assert_equal "A mess.\r\n\r\n--Geoff Maciolek\r\nMYCOMPANYNAME, LLC", issue.description
  end

  def test_should_handle_outlook_2010_html_only
    issue = submit_email('outlook_2010_html_only.eml', :issue => {:project => 'ecookbook'})
    assert issue.is_a?(Issue)
    issue.reload
    assert_equal 'Test email', issue.subject
    assert_equal(
      "Simple, unadorned test email generated by Outlook 2010. It is in HTML format, but" \
        " no special formatting has been chosen. I’m going to save this as a draft and then manually" \
        " drop it into the Inbox for scraping by Redmine 3.0.2.",
      issue.description
    )
  end

  test "truncate emails with no setting should add the entire email into the issue" do
    with_settings :mail_handler_body_delimiters => '' do
      issue = submit_email('ticket_on_given_project.eml')
      assert_issue_created(issue)
      assert issue.description.include?('---')
      assert issue.description.include?('This paragraph is after the delimiter')
    end
  end

  test "truncate emails with a single string should truncate the email at the delimiter for the issue" do
    with_settings :mail_handler_body_delimiters => '---' do
      issue = submit_email('ticket_on_given_project.eml')
      assert_issue_created(issue)
      assert issue.description.include?('This paragraph is before delimiters')
      assert issue.description.include?('--- This line starts with a delimiter')
      assert !issue.description.match(/^---\u00A0$/)
      assert !issue.description.include?('This paragraph is after the delimiter')
    end
  end

  test "truncate emails with a single quoted reply should truncate the email at the delimiter with the quoted reply symbols (>)" do
    with_settings :mail_handler_body_delimiters => '--- Reply above. Do not remove this line. ---' do
      journal = submit_email('issue_update_with_quoted_reply_above.eml')
      assert journal.is_a?(Journal)
      assert journal.notes.include?('An update to the issue by the sender.')
      assert !journal.notes.match(Regexp.escape("--- Reply above. Do not remove this line. ---"))
      assert !journal.notes.include?('Looks like the JSON api for projects was missed.')
    end
  end

  test "truncate emails with multiple quoted replies should truncate the email at the delimiter with the quoted reply symbols (>)" do
    with_settings :mail_handler_body_delimiters => '--- Reply above. Do not remove this line. ---' do
      journal = submit_email('issue_update_with_multiple_quoted_reply_above.eml')
      assert journal.is_a?(Journal)
      assert journal.notes.include?('An update to the issue by the sender.')
      assert !journal.notes.match(Regexp.escape("--- Reply above. Do not remove this line. ---"))
      assert !journal.notes.include?('Looks like the JSON api for projects was missed.')
    end
  end

  test "truncate emails with multiple strings should truncate the email at the first delimiter found (BREAK)" do
    with_settings :mail_handler_body_delimiters => "---\nBREAK" do
      issue = submit_email('ticket_on_given_project.eml')
      assert_issue_created(issue)
      assert issue.description.include?('This paragraph is before delimiters')
      assert !issue.description.include?('BREAK')
      assert !issue.description.include?('This paragraph is between delimiters')
      assert !issue.description.match(/^---$/)
      assert !issue.description.include?('This paragraph is after the delimiter')
    end
  end

  test "truncate emails using a regex delimiter" do
    delimiter = "On .*, .* at .*, .* <.*<mailto:.*>> wrote:"
    with_settings :mail_handler_enable_regex_delimiters => '1', :mail_handler_body_delimiters => delimiter do
      issue = submit_email('ticket_reply_from_mail.eml')
      assert_issue_created(issue)
      assert issue.description.include?('This paragraph is before delimiter')
      assert !issue.description.include?('On Wed, 11 Oct at 1:05 PM, Jon Smith <jsmith@somenet.foo<mailto:jsmith@somenet.foo>> wrote:')
      assert !issue.description.include?('This paragraph is after the delimiter')
    end

    with_settings :mail_handler_enable_regex_delimiters => '0', :mail_handler_body_delimiters => delimiter do
      issue = submit_email('ticket_reply_from_mail.eml')
      assert_issue_created(issue)
      assert issue.description.include?('This paragraph is before delimiter')
      assert issue.description.include?('On Wed, 11 Oct at 1:05 PM, Jon Smith <jsmith@somenet.foo<mailto:jsmith@somenet.foo>> wrote:')
      assert issue.description.include?('This paragraph is after the delimiter')
    end
  end

  def test_attachments_that_match_mail_handler_excluded_filenames_should_be_ignored
    with_settings :mail_handler_excluded_filenames => "*.vcf,\n *.jpg" do
      issue = submit_email('ticket_with_attachment.eml', :issue => {:project => 'onlinestore'})
      assert issue.is_a?(Issue)
      assert !issue.new_record?
      assert_equal 0, issue.reload.attachments.size
    end
  end

  def test_attachments_that_match_mail_handler_excluded_filenames_by_regex_should_be_ignored
    with_settings :mail_handler_excluded_filenames => '.+\.vcf,(pa|nut)ella\.jpg',
                  :mail_handler_enable_regex_excluded_filenames => 1 do
      issue = submit_email('ticket_with_attachment.eml', :issue => {:project => 'onlinestore'})
      assert issue.is_a?(Issue)
      assert !issue.new_record?
      assert_equal 0, issue.reload.attachments.size
    end
  end

  def test_attachments_that_do_not_match_mail_handler_excluded_filenames_should_be_attached
    with_settings :mail_handler_excluded_filenames => '*.vcf, *.gif' do
      issue = submit_email('ticket_with_attachment.eml', :issue => {:project => 'onlinestore'})
      assert issue.is_a?(Issue)
      assert !issue.new_record?
      assert_equal 1, issue.reload.attachments.size
    end
  end

  def test_email_with_long_subject_line
    issue = submit_email('ticket_with_long_subject.eml')
    assert issue.is_a?(Issue)
    str =
      'New ticket on a given project with a very long subject line' \
        ' which exceeds 255 chars and should not be ignored but chopped off.' \
        ' And if the subject line is still not long enough, we just add more text.' \
        ' And more text. Wow, this is really annoying.' \
        ' Especially, if you have nothing to say...'
    assert_equal issue.subject, str[0, 255]
  end

  def test_first_keyword_should_be_matched
    issue = submit_email('ticket_with_duplicate_keyword.eml', :allow_override => 'priority')
    assert issue.is_a?(Issue)
    assert_equal 'High', issue.priority.name
  end

  def test_keyword_after_delimiter_should_be_ignored
    with_settings :mail_handler_body_delimiters => "== DELIMITER ==" do
      issue = submit_email('ticket_with_keyword_after_delimiter.eml', :allow_override => 'priority')
      assert issue.is_a?(Issue)
      assert_equal 'Normal', issue.priority.name
    end
  end

  def test_new_user_from_attributes_should_return_valid_user
    to_test = {
      # [address, name] => [login, firstname, lastname]
      ['jsmith@example.net', nil] => ['jsmith@example.net', 'jsmith', '-'],
      ['jsmith@example.net', 'John'] => ['jsmith@example.net', 'John', '-'],
      ['jsmith@example.net', 'John Smith'] => ['jsmith@example.net', 'John', 'Smith'],
      ['jsmith@example.net', 'John Paul Smith'] => ['jsmith@example.net', 'John', 'Paul Smith'],
      ['jsmith@example.net', 'AVeryLongFirstnameThatExceedsTheMaximumLength Smith'] =>
         ['jsmith@example.net', 'AVeryLongFirstnameThatExceedsT', 'Smith'],
      ['jsmith@example.net', 'John AVeryLongLastnameThatExceedsTheMaximumLength'] =>
         ['jsmith@example.net', 'John', 'AVeryLongLastnameThatExceedsTh']
    }
    to_test.each do |attrs, expected|
      user = MailHandler.new_user_from_attributes(attrs.first, attrs.last)
      assert user.valid?, user.errors.full_messages.to_s
      assert_equal attrs.first, user.mail
      assert_equal expected[0], user.login
      assert_equal expected[1], user.firstname
      assert_equal expected[2], user.lastname
      assert_equal 'only_my_events', user.mail_notification
    end
  end

  def test_new_user_from_attributes_should_use_default_login_if_invalid
    user = MailHandler.new_user_from_attributes('foo+bar@example.net')
    assert user.valid?
    assert user.login =~ /^user[a-f0-9]+$/
    assert_equal 'foo+bar@example.net', user.mail
  end

  def test_new_user_with_utf8_encoded_fullname_should_be_decoded
    assert_difference 'User.count' do
      issue =
        submit_email(
          'fullname_of_sender_as_utf8_encoded.eml',
          :issue => {:project => 'ecookbook'},
          :unknown_user => 'create'
        )
    end
    user = User.order('id DESC').first
    assert_equal "foo@example.org", user.mail
    assert_equal 'Ää', user.firstname
    assert_equal 'Öö', user.lastname
  end

  def test_new_user_with_fullname_in_parentheses
    assert_difference 'User.count' do
      issue =
        submit_email(
          'fullname_of_sender_in_parentheses.eml',
          :issue => {:project => 'ecookbook'},
          :unknown_user => 'create'
        )
    end
    user = User.order('id DESC').first
    assert_equal "jdoe@example.net", user.mail
    assert_equal 'John', user.firstname
    assert_equal 'Doe', user.lastname
  end

  def test_extract_options_from_env_should_return_options
    options =
      MailHandler.extract_options_from_env(
        {
          'tracker' => 'defect',
          'project' => 'foo',
          'unknown_user' => 'create',
          'no_notification' => '1'
        }
      )
    assert_equal(
      {:issue => {:tracker => 'defect', :project => 'foo'},
       :unknown_user => 'create', :no_notification => '1'},
      options
    )
  end

  def test_safe_receive_should_rescue_exceptions_and_return_false
    MailHandler.stubs(:receive).raises(StandardError.new("Something went wrong"))

    assert_equal false, MailHandler.safe_receive
  end

  def test_smine_signature
    issue = submit_email('smime_signature.eml', :issue => {:project => 'onlinestore'})
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    issue.reload
    assert_equal 'Self-Signed S/MIME signature', issue.subject
    assert_equal User.find_by_login('jsmith'), issue.author
    assert_equal Project.find(2), issue.project
    assert_equal 'smime.sh.txt describes how to create Self-Signed S/MIME Certs.', issue.description
    assert_equal 2, issue.attachments.size
    assert_equal 'smime.sh.txt', issue.attachments[0].filename
    assert_equal 'text/plain', issue.attachments[0].content_type
    assert_equal 'smime.p7s', issue.attachments[1].filename
    assert_equal 'application/x-pkcs7-signature', issue.attachments[1].content_type
  end

  private

  def submit_email(filename, options={})
    raw = IO.read(File.join(FIXTURES_PATH, filename))
    yield raw if block_given?
    MailHandler.receive(raw, options)
  end

  def assert_issue_created(issue)
    assert issue.is_a?(Issue)
    assert !issue.new_record?
    issue.reload
  end
end
