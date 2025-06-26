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

require File.expand_path('../../test_helper', __FILE__)

class CommentTest < ActiveSupport::TestCase
  fixtures :users, :email_addresses, :news, :comments, :projects, :enabled_modules,
           :user_preferences, :roles, :members, :member_roles

  def setup
    User.current = nil
    @jsmith = User.find(2)
    @news = News.find(1)
  end

  def test_create
    comment = Comment.new(:commented => @news, :author => @jsmith, :comments => "my comment")
    assert comment.save
    @news.reload
    assert_equal 2, @news.comments_count
  end

  def test_create_should_send_notification
    Watcher.create!(:watchable => @news, :user => @jsmith)

    with_settings :notified_events => %w(news_comment_added) do
      assert_difference 'ActionMailer::Base.deliveries.size', 2 do
        Comment.create!(:commented => @news, :author => @jsmith, :comments => "my comment")
      end
    end
  end

  def test_validate
    comment = Comment.new(:commented => @news)
    assert !comment.save
    assert_equal 2, comment.errors.count
  end

  def test_destroy
    comment = Comment.find(1)
    assert comment.destroy
    @news.reload
    assert_equal 0, @news.comments_count
  end
end
