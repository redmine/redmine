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
    assert_equal @project.id, h.dig(:data, :wiki_page, :project, :id)
  end
end
