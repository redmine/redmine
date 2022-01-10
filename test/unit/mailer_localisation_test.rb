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

class MailerLocalisationTest < ActiveSupport::TestCase
  include Redmine::I18n
  include Rails::Dom::Testing::Assertions
  fixtures :projects, :enabled_modules, :issues, :users, :email_addresses, :user_preferences, :members,
           :member_roles, :roles, :documents, :attachments, :news,
           :tokens, :journals, :journal_details, :changesets,
           :trackers, :projects_trackers,
           :issue_statuses, :enumerations, :messages, :boards, :repositories,
           :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions,
           :versions,
           :comments

  def setup
    ActionMailer::Base.deliveries.clear
    Setting.plain_text_mail = '0'
    Setting.default_language = 'en'
    User.current = nil
  end

  # test mailer methods for each language
  def test_issue_add
    issue = Issue.find(1)
    with_each_user_language do |user|
      assert Mailer.issue_add(user, issue).deliver_now
    end
  end

  def test_issue_edit
    journal = Journal.find(1)
    with_each_user_language do |user|
      assert Mailer.issue_edit(user, journal).deliver_now
    end
  end

  def test_document_added
    document = Document.find(1)
    author = User.find(2)
    with_each_user_language do |user|
      assert Mailer.document_added(user, document, author).deliver_now
    end
  end

  def test_attachments_added
    attachements = [ Attachment.find_by_container_type('Document') ]
    with_each_user_language do |user|
      assert Mailer.attachments_added(user, attachements).deliver_now
    end
  end

  def test_news_added
    news = News.first
    with_each_user_language do |user|
      assert Mailer.news_added(user, news).deliver_now
    end
  end

  def test_news_comment_added
    comment = Comment.find(2)
    with_each_user_language do |user|
      assert Mailer.news_comment_added(user, comment).deliver_now
    end
  end

  def test_message_posted
    message = Message.first
    with_each_user_language do |user|
      assert Mailer.message_posted(user, message).deliver_now
    end
  end

  def test_wiki_content_added
    content = WikiContent.find(1)
    with_each_user_language do |user|
      assert Mailer.wiki_content_added(user, content).deliver_now
    end
  end

  def test_wiki_content_updated
    content = WikiContent.find(1)
    with_each_user_language do |user|
      assert Mailer.wiki_content_updated(user, content).deliver_now
    end
  end

  def test_account_information
    with_each_user_language do |user|
      assert Mailer.account_information(user, 'pAsswORd').deliver_now
    end
  end

  def test_lost_password
    token = Token.find(2)
    with_each_user_language do |user|
      assert Mailer.lost_password(user, token).deliver_now
    end
  end

  def test_register
    token = Token.find(1)
    with_each_user_language do |user|
      assert Mailer.register(user, token).deliver_now
    end
  end

  def test_test_email
    with_each_user_language do |user|
      assert Mailer.test_email(user).deliver_now
    end
  end

  private

  def with_each_user_language(&block)
    user = User.find(2)
    valid_languages.each do |lang|
      user.update_attribute :language, lang
      yield user
    end
  end
end
