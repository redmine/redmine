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

require_relative '../../../../test_helper'

class Redmine::Acts::MentionableTest < ActiveSupport::TestCase
  def test_mentioned_users_with_user_mention
    to_test = %w(@dlopper @dlopper! @dlopper? @dlopper. @dlopper,)  # rubocop:disable Lint/PercentStringArray

    to_test.each do |item|
      issue = Issue.generate!(project_id: 1, description: item)
      assert_equal [User.find(3)], issue.mentioned_users
    end
  end

  def test_mentioned_users_with_user_mention_having_mail_as_login
    user = User.generate!(login: "foo@example.net")
    User.add_to_project(user, Project.find(1), Role.find(1))

    issue = Issue.generate!(project_id: 1, description: '@dlopper and @foo@example.net')

    assert_equal [3, user.id], issue.mentioned_users.ids.sort
  end

  def test_mentioned_users_with_multiple_mentions
    issue = Issue.generate!(project_id: 1, description: 'Hello @dlopper, @jsmith.')

    assert_equal [User.find(2), User.find(3)], issue.mentioned_users.sort_by(&:id)
  end

  def test_mentioned_users_should_not_mention_same_user_multiple_times
    issue = Issue.generate!(project_id: 1, description: '@dlopper @jsmith @dlopper')

    assert_equal [User.find(2), User.find(3)], issue.mentioned_users.sort_by(&:id)
  end

  def test_mentioned_users_should_include_only_active_users
    # disable dlopper account
    user = User.find(3)
    user.status = User::STATUS_LOCKED
    user.save

    issue = Issue.generate!(project_id: 1, description: '@dlopper @jsmith')

    assert_equal [User.find(2)], issue.mentioned_users
  end

  def test_mentioned_users_should_include_only_visible_users
    User.current = nil
    Role.non_member.update! users_visibility: 'members_of_visible_projects'
    Role.anonymous.update! users_visibility: 'members_of_visible_projects'
    user = User.generate!

    issue = Issue.generate!(project_id: 1, description: "@jsmith @#{user.login}")

    assert_equal [User.find(2)], issue.mentioned_users
  end

  def test_mentioned_users_should_not_include_mentioned_users_in_existing_content
    issue = Issue.generate!(project_id: 1, description: 'Hello @dlopper')

    assert issue.save
    assert_equal [User.find(3)], issue.mentioned_users

    issue.description = 'Hello @dlopper and @jsmith'
    issue.save

    assert_equal [User.find(2)], issue.mentioned_users
  end

  def test_mentioned_users_should_not_include_users_wrapped_in_pre_tags_for_textile
    description = <<~STR
      <pre>
      Hello @jsmith
      </pre>
    STR

    with_settings text_formatting: 'textile' do
      issue = Issue.generate!(project_id: 1, description: description)

      assert_equal [], issue.mentioned_users
    end
  end

  def test_mentioned_users_should_not_include_users_wrapped_in_pre_tags_for_markdown
    description = <<~STR
      ```
      Hello @jsmith
      ```
    STR

    with_settings text_formatting: 'common_mark' do
      issue = Issue.generate!(project_id: 1, description: description)

      assert_equal [], issue.mentioned_users
    end
  end

  def test_mentioned_users_should_not_include_users_wrapped_in_pre_tags_for_common_mark
    description = <<~STR
      ```
      Hello @jsmith
      ```
    STR

    with_settings text_formatting: 'common_mark' do
      issue = Issue.generate!(project_id: 1, description: description)

      assert_equal [], issue.mentioned_users
    end
  end

  def test_notified_mentions
    issue = Issue.generate!(project_id: 1, description: 'Hello @dlopper, @jsmith.')

    assert_equal [User.find(2), User.find(3)], issue.notified_mentions.sort_by(&:id)
  end

  def test_notified_mentions_should_not_include_users_who_out_of_all_email
    User.find(3).update!(mail_notification: :none)
    issue = Issue.generate!(project_id: 1, description: "Hello @dlopper, @jsmith.")

    assert_equal [User.find(2)], issue.notified_mentions
  end

  def test_notified_mentions_should_not_include_users_who_cannot_view_the_object
    user = User.find(3)

    # User dlopper does not have access to project "Private child of eCookbook"
    issue = Issue.generate!(project_id: 5, description: "Hello @dlopper, @jsmith.")

    assert !issue.notified_mentions.include?(user)
  end
end
