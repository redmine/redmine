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

class WebhookPayloadTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @dlopper = User.find_by_login 'dlopper'
    @project = Project.find 'ecookbook'
    @issue = @project.issues.first
  end

  test "issue update payload should contain journal" do
    @issue.init_journal(@dlopper)
    @issue.subject = "new subject"
    @issue.save
    p = WebhookPayload.new('issue.updated', @issue, @dlopper)
    assert h = p.to_h
    assert_equal 'issue.updated', h[:type]
    assert j = h.dig(:data, :journal)
    assert_equal 'Dave Lopper', j[:user][:name]
    assert i = h.dig(:data, :issue)
    assert_equal 'new subject', i[:subject], i.inspect
  end

  test "should compute payload of deleted issue" do
    @issue.destroy
    p = WebhookPayload.new('issue.deleted', @issue, @dlopper)
    assert h = p.to_h
    assert_equal 'issue.deleted', h[:type]
    assert_nil h.dig(:data, :journal)
    assert i = h.dig(:data, :issue)
    assert_equal @issue.subject, i[:subject], i.inspect
  end

  test "wiki page created payload should contain page details" do
    wiki = @project.wiki
    page = WikiPage.new(:title => 'Test Page', :wiki => wiki)
    page.content = WikiContent.new(text: 'Test content', author: @dlopper)
    page.save!

    p = WebhookPayload.new('wiki_page.created', page, @dlopper)
    assert h = p.to_h
    assert_equal 'wiki_page.created', h[:type]
    assert_equal 'Test_Page', h.dig(:data, :wiki_page, :title)
    assert_equal 'Test content', h.dig(:data, :wiki_page, :text)
    assert_equal @dlopper.name, h.dig(:data, :wiki_page, :author, :name)
  end

  test "wiki page updated payload should contain updated timestamp" do
    wiki = @project.wiki
    page = WikiPage.new(wiki: wiki, title: 'Test Page')
    page.content = WikiContent.new(text: 'Initial content', author: @dlopper)
    page.save!

    page.content.text = 'Updated content'
    page.content.save!
    page.reload

    p = WebhookPayload.new('wiki_page.updated', page, @dlopper)
    h = p.to_h
    assert_equal 'wiki_page.updated', h[:type]
    assert_equal 'Updated content', h.dig(:data, :wiki_page, :text)
  end

  test "wiki page deleted payload should contain basic info" do
    wiki = @project.wiki
    page = WikiPage.new(wiki: wiki, title: 'Test Page')
    page.content = WikiContent.new(text: 'Test content', author: @dlopper)
    page.save!

    page.destroy

    p = WebhookPayload.new('wiki_page.deleted', page, @dlopper)
    h = p.to_h
    assert_equal 'wiki_page.deleted', h[:type]
    assert_equal 'Test_Page', h.dig(:data, :wiki_page, :title)
  end

  test "time entry created payload should contain time entry details" do
    time_entry = TimeEntry.generate!

    p = WebhookPayload.new('time_entry.created', time_entry, @dlopper)
    assert h = p.to_h
    assert_equal 'time_entry.created', h[:type]
    assert_equal time_entry.hours, h.dig(:data, :time_entry, :hours)
  end

  test "time entry updated payload should contain updated timestamp" do
    time_entry = TimeEntry.first

    time_entry.hours = 2.5
    time_entry.save!

    p = WebhookPayload.new('time_entry.updated', time_entry, @dlopper)
    h = p.to_h
    assert_equal 'time_entry.updated', h[:type]
    assert_equal 2.5, h.dig(:data, :time_entry, :hours)
  end

  test "time entry deleted payload should contain basic info" do
    time_entry = TimeEntry.first
    time_entry.destroy

    p = WebhookPayload.new('time_entry.deleted', time_entry, @dlopper)
    h = p.to_h
    assert_equal 'time_entry.deleted', h[:type]
    assert_equal 4.25, h.dig(:data, :time_entry, :hours)
  end

  test "news created payload should contain news details" do
    news = News.new(project: Project.first, author: @dlopper, title: "Webhook title", description: "Webhook description")
    news.save!

    p = WebhookPayload.new('news.created', news, @dlopper)
    assert h = p.to_h
    assert_equal 'news.created', h[:type]
    assert_equal news.title, h.dig(:data, :news, :title)
  end

  test "news updated payload should contain updated timestamp" do
    news = News.first

    news.title = 'Updated title'
    news.save!

    p = WebhookPayload.new('news.updated', news, @dlopper)
    h = p.to_h
    assert_equal 'news.updated', h[:type]
    assert_equal 'Updated title', h.dig(:data, :news, :title)
  end

  test "news deleted payload should contain basic info" do
    news = News.first
    news.destroy

    p = WebhookPayload.new('news.deleted', news, @dlopper)
    h = p.to_h
    assert_equal 'news.deleted', h[:type]
    assert_equal 'eCookbook first release !', h.dig(:data, :news, :title)
  end

  test "version created payload should contain version details" do
    version = Version.generate!

    p = WebhookPayload.new('version.created', version, @dlopper)
    assert h = p.to_h
    assert_equal 'version.created', h[:type]
    assert_equal version.name, h.dig(:data, :version, :name)
  end

  test "version updated payload should contain updated timestamp" do
    version = Version.first

    version.name = 'Updated name'
    version.save!

    p = WebhookPayload.new('version.updated', version, @dlopper)
    h = p.to_h
    assert_equal 'version.updated', h[:type]
    assert_equal 'Updated name', h.dig(:data, :version, :name)
  end

  test "version deleted payload should contain basic info" do
    version = Version.first
    version.destroy

    p = WebhookPayload.new('version.deleted', version, @dlopper)
    h = p.to_h
    assert_equal 'version.deleted', h[:type]
    assert_equal '0.1', h.dig(:data, :version, :name)
  end
end
