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

class CommentsControllerTest < Redmine::ControllerTest
  def setup
    User.current = nil
  end

  def test_add_comment
    @request.session[:user_id] = 2
    post(
      :create,
      :params => {
        :id => 1,
        :comment => {
          :comments => 'This is a test comment'
        }
      }
    )
    assert_redirected_to '/news/1'

    comment = News.find(1).comments.last
    assert_not_nil comment
    assert_equal 'This is a test comment', comment.comments
    assert_equal User.find(2), comment.author
  end

  def test_empty_comment_should_not_be_added
    @request.session[:user_id] = 2
    assert_no_difference 'Comment.count' do
      post(
        :create,
        :params => {
          :id => 1,
          :comment => {
            :comments => ''
          }
        }
      )
      assert_response :redirect
      assert_redirected_to '/news/1'
    end
  end

  def test_create_should_be_denied_if_news_is_not_commentable
    News.any_instance.stubs(:commentable?).returns(false)
    @request.session[:user_id] = 2
    assert_no_difference 'Comment.count' do
      post(
        :create,
        :params => {
          :id => 1,
          :comment => {
            :comments => 'This is a test comment'
          }
        }
      )
      assert_response :forbidden
    end
  end

  def test_destroy_comment
    comments_count = News.find(1).comments.size
    @request.session[:user_id] = 2
    delete(
      :destroy,
      :params => {
        :id => 1,
        :comment_id => 2
      }
    )
    assert_redirected_to '/news/1'
    assert_nil Comment.find_by_id(2)
    assert_equal comments_count - 1, News.find(1).comments.size
  end
end
