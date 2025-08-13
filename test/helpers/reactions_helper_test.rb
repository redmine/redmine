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

class ReactionsHelperTest < ActionView::TestCase
  include ReactionsHelper

  setup do
    User.current = users(:users_002)
    Setting.reactions_enabled = '1'
  end

  test 'reaction_id_for generates a DOM id' do
    assert_equal "reaction_issue_1", reaction_id_for(issues(:issues_001))
  end

  test 'reaction_button returns nil when feature is disabled' do
    Setting.reactions_enabled = '0'

    assert_nil reaction_button(issues(:issues_004))
  end

  test 'reaction_button returns nil when object not visible' do
    User.current = users(:users_003)

    assert_nil reaction_button(issues(:issues_004))
  end

  test 'reaction_button for anonymous users shows readonly button' do
    User.current = nil

    result = reaction_button(journals(:journals_001))

    assert_select_in result, 'span.reaction-button.readonly[title=?]', 'John Smith'
    assert_select_in result, 'a.reaction-button', false
  end

  test 'reaction_button for inactive projects shows readonly button' do
    issue6 = issues(:issues_006)
    issue6.project.update!(status: Project::STATUS_CLOSED)

    result = reaction_button(issue6)

    assert_select_in result, 'span.reaction-button.readonly[title=?]', 'John Smith'
    assert_select_in result, 'a.reaction-button', false
  end

  test 'reaction_button includes no tooltip when the object has no reactions' do
    issue = issues(:issues_002) # Issue without reactions
    result = reaction_button(issue)

    assert_select_in result, 'a.reaction-button[title]', false
  end

  test 'reaction_button includes tooltip with all usernames when reactions are 10 or fewer' do
    issue = issues(:issues_002)

    reactions = build_reactions(10)
    issue.reactions += reactions

    result = with_locale 'en' do
      reaction_button(issue)
    end

    # The tooltip should display usernames in order of newest reactions.
    expected_tooltip = 'Bob9 Doe, Bob8 Doe, Bob7 Doe, Bob6 Doe, Bob5 Doe, ' \
                       'Bob4 Doe, Bob3 Doe, Bob2 Doe, Bob1 Doe, and Bob0 Doe'

    assert_select_in result, 'a.reaction-button[title=?]', expected_tooltip
  end

  test 'reaction_button includes tooltip with 10 usernames and others count when reactions exceed 10' do
    issue = issues(:issues_002)

    reactions = build_reactions(11)
    issue.reactions += reactions

    result = with_locale 'en' do
      reaction_button(issue)
    end

    expected_tooltip = 'Bob10 Doe, Bob9 Doe, Bob8 Doe, Bob7 Doe, Bob6 Doe, ' \
                       'Bob5 Doe, Bob4 Doe, Bob3 Doe, Bob2 Doe, Bob1 Doe, and 1 other'

    assert_select_in result, 'a.reaction-button[title=?]', expected_tooltip
  end

  test 'reaction_button should be label less when no reactions' do
    issue = issues(:issues_002)

    result = with_locale('en') do
      reaction_button(issue)
    end
    assert_select_in result, 'a.reaction-button' do
      assert_select 'span.icon-label', false
    end

    # readonly
    User.current = nil
    result = with_locale('en') do
      reaction_button(issue)
    end
    assert_select_in result, 'span.reaction-button.readonly' do
      assert_select 'span.icon-label', false
    end
  end

  test 'reaction_button should not count and display non-visible users' do
    issue2 = issues(:issues_002)

    issue2.reaction_detail = Reaction::Detail.new(
      visible_users: users(:users_002, :users_003)
    )

    result = with_locale('en') do
      reaction_button(issue2)
    end

    assert_select_in result, 'a.reaction-button[title=?]', 'John Smith and Dave Lopper'

    # When all users are non-visible users
    issue2.reaction_detail = Reaction::Detail.new(
      visible_users: []
    )

    result = with_locale('en') do
      reaction_button(issue2)
    end

    assert_select_in result, 'a.reaction-button[title]', false
    assert_select_in result, 'a.reaction-button' do
      assert_select 'span.icon-label', false
    end
  end

  test 'reaction_button formats the tooltip content based on the support.array settings of each locale' do
    result = with_locale('ja') do
      reaction_button(issues(:issues_001))
    end

    assert_select_in result, 'a.reaction-button[title=?]', 'Dave Lopper、John Smith、Redmine Admin'
  end

  test 'reaction_button for reacted object' do
    User.current = users(:users_002)

    issue = issues(:issues_001)

    result = with_locale('en') do
      reaction_button(issue)
    end
    tooltip = 'Dave Lopper, John Smith, and Redmine Admin'

    assert_select_in result, 'span.reaction-button-wrapper[data-reaction-button-id=?]', 'reaction_issue_1' do
      href = reaction_path(issue.reaction_detail.user_reaction, object_type: 'Issue', object_id: 1)

      assert_select 'a.icon.reaction-button.reacted[href=?]', href do
        assert_select 'use[href*=?]', 'thumb-up-filled'
        assert_select 'span.icon-label', '3'
      end

      assert_select 'span.reaction-button', false
    end
  end

  test 'reaction_button for non-reacted object' do
    User.current = users(:users_004)

    issue = issues(:issues_001)

    result = with_locale('en') do
      reaction_button(issue)
    end
    tooltip = 'Dave Lopper, John Smith, and Redmine Admin'

    assert_select_in result, 'span.reaction-button-wrapper[data-reaction-button-id=?]', 'reaction_issue_1' do
      href = reactions_path(object_type: 'Issue', object_id: 1)

      assert_select 'a.icon.reaction-button[href=?]', href do
        assert_select 'use[href*=?]', 'thumb-up'
        assert_select 'span.icon-label', '3'
      end

      assert_select 'span.reaction-button', false
    end
  end

  private

  def build_reactions(count)
    Array.new(count) do |i|
      Reaction.new(user: User.generate!(firstname: "Bob#{i}"))
    end
  end
end
