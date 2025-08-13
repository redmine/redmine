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

class ReactionsControllerTest < Redmine::ControllerTest
  setup do
    Setting.reactions_enabled = '1'
    # jsmith
    @request.session[:user_id] = users(:users_002).id
  end

  test 'create for issue' do
    issue = issues(:issues_002)

    assert_difference(
      ->{ Reaction.count } => 1,
      ->{ issue.reactions.by(users(:users_002)).count } => 1
    ) do
      post :create, params: {
        object_type: 'Issue',
        object_id: issue.id
      }, xhr: true
    end

    assert_response :success
  end

  test 'create for journal' do
    journal = journals(:journals_005)

    assert_difference(
      ->{ Reaction.count } => 1,
      ->{ journal.reactions.by(users(:users_002)).count } => 1
    ) do
      post :create, params: {
        object_type: 'Journal',
        object_id: journal.id
      }, xhr: true
    end

    assert_response :success
  end

  test 'create for news' do
    news = news(:news_002)

    assert_difference(
      ->{ Reaction.count } => 1,
      ->{ news.reactions.by(users(:users_002)).count } => 1
    ) do
      post :create, params: {
        object_type: 'News',
        object_id: news.id
      }, xhr: true
    end

    assert_response :success
  end

  test 'create reaction for comment' do
    comment = comments(:comments_002)

    assert_difference(
      ->{ Reaction.count } => 1,
      ->{ comment.reactions.by(users(:users_002)).count } => 1
    ) do
      post :create, params: {
        object_type: 'Comment',
        object_id: comment.id
      }, xhr: true
    end

    assert_response :success
  end

  test 'create for message' do
    message = messages(:messages_001)

    assert_difference(
      ->{ Reaction.count } => 1,
      ->{ message.reactions.by(users(:users_002)).count } => 1
    ) do
      post :create, params: {
        object_type: 'Message',
        object_id: message.id
      }, xhr: true
    end

    assert_response :success
  end

  test 'destroy for issue' do
    reaction = reactions(:reaction_005)

    assert_difference 'Reaction.count', -1 do
      delete :destroy, params: {
        id: reaction.id,
        # Issue (id=6)
        object_type: reaction.reactable_type,
        object_id: reaction.reactable_id
      }, xhr: true
    end

    assert_response :success
    assert_not Reaction.exists?(reaction.id)
  end

  test 'destroy for journal' do
    reaction = reactions(:reaction_006)

    assert_difference 'Reaction.count', -1 do
      delete :destroy, params: {
        id: reaction.id,
        object_type: reaction.reactable_type,
        object_id: reaction.reactable_id
      }, xhr: true
    end

    assert_response :success
    assert_not Reaction.exists?(reaction.id)
  end

  test 'destroy for news' do
    # For News(id=3)
    reaction = reactions(:reaction_010)

    assert_difference 'Reaction.count', -1 do
      delete :destroy, params: {
        id: reaction.id,
        object_type: reaction.reactable_type,
        object_id: reaction.reactable_id
      }, xhr: true
    end

    assert_response :success
    assert_not Reaction.exists?(reaction.id)
  end

  test 'destroy for comment' do
    # For Comment(id=1)
    reaction = reactions(:reaction_008)

    assert_difference 'Reaction.count', -1 do
      delete :destroy, params: {
        id: reaction.id,
        object_type: reaction.reactable_type,
        object_id: reaction.reactable_id
      }, xhr: true
    end

    assert_response :success
    assert_not Reaction.exists?(reaction.id)
  end

  test 'destroy for message' do
    reaction = reactions(:reaction_009)

    assert_difference 'Reaction.count', -1 do
      delete :destroy, params: {
        id: reaction.id,
        object_type: reaction.reactable_type,
        object_id: reaction.reactable_id
      }, xhr: true
    end

    assert_response :success
    assert_not Reaction.exists?(reaction.id)
  end

  test 'create should respond with 403 when feature is disabled' do
    Setting.reactions_enabled = '0'
    # admin
    @request.session[:user_id] = users(:users_001).id

    assert_no_difference 'Reaction.count' do
      post :create, params: {
        object_type: 'Issue',
        object_id: issues(:issues_002).id
      }, xhr: true
    end
    assert_response :forbidden
  end

  test 'destroy should respond with 403 when feature is disabled' do
    Setting.reactions_enabled = '0'
    # admin
    @request.session[:user_id] = users(:users_001).id

    reaction = reactions(:reaction_001)
    assert_no_difference 'Reaction.count' do
      delete :destroy, params: {
        id: reaction.id,
        object_type: reaction.reactable_type,
        object_id: reaction.reactable_id
      }, xhr: true
    end
    assert_response :forbidden
  end

  test 'create by anonymou user should respond with 401 when feature is disabled' do
    Setting.reactions_enabled = '0'
    @request.session[:user_id] = nil

    assert_no_difference 'Reaction.count' do
      post :create, params: {
        object_type: 'Issue',
        object_id: issues(:issues_002).id
      }, xhr: true
    end
    assert_response :unauthorized
  end

  test 'create by anonymous user should respond with 401' do
    @request.session[:user_id] = nil

    assert_no_difference 'Reaction.count' do
      post :create, params: {
        object_type: 'Issue',
        # Issue(id=1) is an issue in a public project
        object_id: issues(:issues_001).id
      }, xhr: true
    end

    assert_response :unauthorized
  end

  test 'destroy by anonymous user should respond with 401' do
    @request.session[:user_id] = nil

    reaction = reactions(:reaction_002)
    assert_no_difference 'Reaction.count' do
      delete :destroy, params: {
        id: reaction.id,
        object_type: reaction.reactable_type,
        object_id: reaction.reactable_id
      }, xhr: true
    end

    assert_response :unauthorized
  end

  test 'create when reaction already exists should not create a new reaction and succeed' do
    assert_no_difference 'Reaction.count' do
      post :create, params: {
        object_type: 'Comment',
        # user(jsmith) has already reacted to Comment(id=1)
        object_id: comments(:comments_001).id
      }, xhr: true
    end

    assert_response :success
  end

  test 'destroy another user reaction should not destroy the reaction and succeed' do
    # admin user's reaction
    reaction = reactions(:reaction_001)

    assert_no_difference 'Reaction.count' do
      delete :destroy, params: {
        id: reaction.id,
        object_type: reaction.reactable_type,
        object_id: reaction.reactable_id
      }, xhr: true
    end

    assert_response :success
  end

  test 'destroy nonexistent reaction' do
    # For Journal(id=4)
    reaction = reactions(:reaction_006)
    reaction.destroy!

    assert_not Reaction.exists?(reaction.id)

    assert_no_difference 'Reaction.count' do
      delete :destroy, params: {
        id: reaction.id,
        object_type: reaction.reactable_type,
        object_id: reaction.reactable_id
      }, xhr: true
    end

    assert_response :success
  end

  test 'create with invalid object type should respond with 403' do
    # admin
    @request.session[:user_id] = users(:users_001).id

    post :create, params: {
      object_type: 'InvalidType',
      object_id: 1
    }, xhr: true

    assert_response :forbidden
  end

  test 'create without permission to view should respond with 403' do
    # dlopper
    @request.session[:user_id] = users(:users_003).id

    assert_no_difference 'Reaction.count' do
      post :create, params: {
        object_type: 'Issue',
        # dlopper is not a member of the project where the issue (id=4) belongs.
        object_id: issues(:issues_004).id
      }, xhr: true
    end

    assert_response :forbidden
  end

  test 'destroy without permission to view should respond with 403' do
    # dlopper
    @request.session[:user_id] = users(:users_003).id

    # For Issue(id=6)
    reaction = reactions(:reaction_005)

    assert_no_difference 'Reaction.count' do
      delete :destroy, params: {
        id: reaction.id,
        object_type: reaction.reactable_type,
        object_id: reaction.reactable_id
      }, xhr: true
    end

    assert_response :forbidden
  end

  test 'create should respond with 404 for non-JS requests' do
    issue = issues(:issues_002)

    assert_no_difference 'Reaction.count' do
      post :create, params: {
        object_type: 'Issue',
        object_id: issue.id
      } # Sending an HTML request by omitting xhr: true
    end

    assert_response :not_found
  end

  test 'create should respond with 403 when project is closed' do
    issue = issues(:issues_010)
    issue.project.update!(status: Project::STATUS_CLOSED)

    assert_no_difference 'Reaction.count' do
      post :create, params: {
        object_type: 'Issue',
        object_id: issue.id
      }, xhr: true
    end

    assert_response :forbidden
  end

  test 'destroy should respond with 403 when project is closed' do
    reaction = reactions(:reaction_005)
    reaction.reactable.project.update!(status: Project::STATUS_CLOSED)

    assert_no_difference 'Reaction.count' do
      delete :destroy, params: {
        id: reaction.id,
        object_type: reaction.reactable_type,
        object_id: reaction.reactable_id
      }, xhr: true
    end

    assert_response :forbidden
  end
end
