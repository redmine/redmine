# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

class NewsTest < ActiveSupport::TestCase
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :enabled_modules, :news

  def valid_news
    { :title => 'Test news', :description => 'Lorem ipsum etc', :author => User.first }
  end

  def setup
  end

  def test_create_should_send_email_notification
    ActionMailer::Base.deliveries.clear
    news = Project.find(1).news.new(valid_news)

    with_settings :notified_events => %w(news_added) do
      assert news.save
    end
    assert_equal 2, ActionMailer::Base.deliveries.size
  end

  def test_should_include_news_for_projects_with_news_enabled
    project = projects(:projects_001)
    assert project.enabled_modules.any?{ |em| em.name == 'news' }

    # News.latest should return news from projects_001
    assert News.latest.any? { |news| news.project == project }
  end

  def test_should_not_include_news_for_projects_with_news_disabled
    EnabledModule.where(["project_id = ? AND name = ?", 2, 'news']).delete_all
    project = Project.find(2)

    # Add a piece of news to the project
    news = project.news.create(valid_news)

    # News.latest should not return that new piece of news
    assert News.latest.include?(news) == false
  end

  def test_should_only_include_news_from_projects_visibly_to_the_user
    assert News.latest(User.anonymous).all? { |news| news.project.is_public? }
  end

  def test_should_limit_the_amount_of_returned_news
    # Make sure we have a bunch of news stories
    10.times { projects(:projects_001).news.create(valid_news) }
    assert_equal 2, News.latest(users(:users_002), 2).size
    assert_equal 6, News.latest(users(:users_002), 6).size
  end

  def test_should_return_5_news_stories_by_default
    # Make sure we have a bunch of news stories
    10.times { projects(:projects_001).news.create(valid_news) }
    assert_equal 5, News.latest(users(:users_004)).size
  end

  def test_attachments_should_be_visible
    assert News.find(1).attachments_visible?(User.anonymous)
  end

  def test_attachments_should_be_deletable_with_manage_news_permission
    manager = User.find(2)
    assert News.find(1).attachments_deletable?(manager)
  end

  def test_attachments_should_not_be_deletable_without_manage_news_permission
    manager = User.find(2)
    Role.find_by_name('Manager').remove_permission!(:manage_news)
    assert !News.find(1).attachments_deletable?(manager)
  end
end
