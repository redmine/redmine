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

require_relative '../../../test_helper'

class Redmine::ReactionTest < ActiveSupport::TestCase
  setup do
    @user = users(:users_002)
    @issue = issues(:issues_007)
    Setting.reactions_enabled = '1'
  end

  test 'preload_reaction_details preloads ReactionDetail for all objects in the collection' do
    User.current = users(:users_002)

    issue1 = issues(:issues_001)
    issue2 = issues(:issues_002)

    assert_nil issue1.instance_variable_get(:@reaction_detail)
    assert_nil issue2.instance_variable_get(:@reaction_detail)

    Issue.preload_reaction_details([issue1, issue2])

    expected_issue1_reaction_detail = Reaction::Detail.new(
      visible_users: [users(:users_003), users(:users_002), users(:users_001)],
      user_reaction: reactions(:reaction_002)
    )

    # ReactionDetail is already preloaded, so calling reaction_detail does not execute any query.
    assert_no_queries do
      assert_equal expected_issue1_reaction_detail, issue1.reaction_detail

      # Even when an object has no reactions, an empty ReactionDetail is set.
      assert_equal Reaction::Detail.new(
        visible_users: [],
        user_reaction: nil
      ), issue2.reaction_detail
    end
  end

  test 'visible_users in ReactionDetail preloaded by preload_reaction_details does not include non-visible users' do
    current_user = User.current = User.generate!
    visible_user = users(:users_002)
    non_visible_user = User.generate!

    project = Project.generate!
    role = Role.generate!(users_visibility: 'members_of_visible_projects')

    User.add_to_project(current_user, project, role)
    User.add_to_project(visible_user, project, roles(:roles_001))

    issue = Issue.generate!(project: project)

    [current_user, visible_user, non_visible_user].each do |user|
      issue.reactions.create!(user: user)
    end

    Issue.preload_reaction_details([issue])

    # non_visible_user is not visible to current_user because they do not belong to any project.
    assert_equal [visible_user, current_user], issue.reaction_detail.visible_users
  end

  test 'preload_reaction_details does nothing when the reaction feature is disabled' do
    Setting.reactions_enabled = '0'

    User.current = users(:users_002)
    news1 = news(:news_001)

    # Stub the Setting to avoid executing queries for retrieving settings,
    # making it easier to confirm no queries are executed by preload_reaction_details().
    Setting.stubs(:reactions_enabled?).returns(false)

    assert_no_queries do
      News.preload_reaction_details([news1])
    end

    assert_nil news1.instance_variable_get(:@reaction_detail)
  end

  test 'reaction_detail loads and returns ReactionDetail if it is not preloaded' do
    message7 = messages(:messages_007)

    User.current = users(:users_002)
    assert_nil message7.instance_variable_get(:@reaction_detail)

    assert_equal Reaction::Detail.new(
      visible_users: [users(:users_002)],
      user_reaction: reactions(:reaction_009)
    ), message7.reaction_detail
  end

  test 'load_reaction_detail loads ReactionDetail for the object itself' do
    comment1 = comments(:comments_001)

    User.current = users(:users_001)
    assert_nil comment1.instance_variable_get(:@reaction_detail)

    comment1.load_reaction_detail

    assert_equal Reaction::Detail.new(
      visible_users: [users(:users_002)],
      user_reaction: nil
    ), comment1.reaction_detail
  end

  test 'visible? returns true when reactions are enabled and object is visible to user' do
    object = issues(:issues_007)
    user = users(:users_002)

    assert Redmine::Reaction.visible?(object, user)
  end

  test 'visible? returns false when reactions are disabled' do
    Setting.reactions_enabled = '0'

    object = issues(:issues_007)
    user = users(:users_002)

    assert_not Redmine::Reaction.visible?(object, user)
  end

  test 'visible? returns false when object is not visible to user' do
    object = issues(:issues_007)
    user = users(:users_002)

    object.expects(:visible?).with(user).returns(false)

    assert_not Redmine::Reaction.visible?(object, user)
  end

  test 'editable? returns true for various reactable objects when user is logged in, object is visible, and project is active' do
    reactable_objects = {
      issue: issues(:issues_007),
      message: messages(:messages_001),
      news: news(:news_001),
      journal: journals(:journals_001),
      comment: comments(:comments_002)
    }
    user = users(:users_002)

    reactable_objects.each do |type, object|
      assert Redmine::Reaction.editable?(object, user), "Expected editable? to return true for #{type}"
    end
  end

  test 'editable? returns false when user is not logged in' do
    object = issues(:issues_007)
    user = User.anonymous

    assert_not Redmine::Reaction.editable?(object, user)
  end

  test 'editable? returns false when project is inactive' do
    object = issues(:issues_007)
    user = users(:users_002)
    object.project.update!(status: Project::STATUS_ARCHIVED)

    assert_not Redmine::Reaction.editable?(object, user)
  end

  test 'editable? returns false when project is closed' do
    object = issues(:issues_007)
    user = users(:users_002)
    object.project.update!(status: Project::STATUS_CLOSED)

    assert_not Redmine::Reaction.editable?(object, user)
  end
end
