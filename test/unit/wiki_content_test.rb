# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

class WikiContentTest < ActiveSupport::TestCase
  fixtures :projects, :enabled_modules,
           :users, :members, :member_roles, :roles,
           :email_addresses,
           :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions

  def setup
    @wiki = Wiki.find(1)
    @page = @wiki.pages.first
  end

  def test_create
    page = WikiPage.new(:wiki => @wiki, :title => "Page")
    page.content = WikiContent.new(:text => "Content text", :author => User.find(1), :comments => "My comment")
    assert page.save
    page.reload

    content = page.content
    assert_kind_of WikiContent, content
    assert_equal 1, content.version
    assert_equal 1, content.versions.length
    assert_equal "Content text", content.text
    assert_equal "My comment", content.comments
    assert_equal User.find(1), content.author
    assert_equal content.text, content.versions.last.text
  end

  def test_create_should_send_email_notification
    ActionMailer::Base.deliveries.clear
    page = WikiPage.new(:wiki => @wiki, :title => "A new page")
    page.content = WikiContent.new(:text => "Content text", :author => User.find(1), :comments => "My comment")

    with_settings :default_language => 'en', :notified_events => %w(wiki_content_added) do
      assert page.save
    end

    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_include 'wiki page has been added', mail_body(ActionMailer::Base.deliveries.last)
  end

  def test_update_should_be_versioned
    content = @page.content
    version_count = content.version
    content.text = "My new content"
    assert_difference 'WikiContent::Version.count' do
      assert content.save
    end
    content.reload
    assert_equal version_count+1, content.version
    assert_equal version_count+1, content.versions.length

    version = WikiContent::Version.order('id DESC').first
    assert_equal @page.id, version.page_id
    assert_equal '', version.compression
    assert_equal "My new content", version.data
    assert_equal "My new content", version.text
  end

  def test_update_with_gzipped_history
    with_settings :wiki_compression => 'gzip' do
      content = @page.content
      content.text = "My new content"
      assert_difference 'WikiContent::Version.count' do
        assert content.save
      end
    end

    version = WikiContent::Version.order('id DESC').first
    assert_equal @page.id, version.page_id
    assert_equal 'gzip', version.compression
    assert_not_equal "My new content", version.data
    assert_equal "My new content", version.text
  end

  def test_update_should_send_email_notification
    ActionMailer::Base.deliveries.clear
    content = @page.content
    content.text = "My new content"

    with_settings :notified_events => %w(wiki_content_updated), :default_language => 'en' do
      assert content.save
    end

    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_include 'wiki page has been updated', mail_body(ActionMailer::Base.deliveries.last)
  end

  def test_fetch_history
    assert !@page.content.versions.empty?
    @page.content.versions.each do |version|
      assert_kind_of String, version.text
    end
  end

  def test_large_text_should_not_be_truncated_to_64k
    page = WikiPage.new(:wiki => @wiki, :title => "Big page")
    page.content = WikiContent.new(:text => "a" * 500.kilobyte, :author => User.find(1))
    assert page.save
    page.reload
    assert_equal 500.kilobyte, page.content.text.size
  end

  def test_current_version
    content = WikiContent.find(11)
    assert_equal true, content.current_version?
    assert_equal true, content.versions.order('version DESC').first.current_version?
    assert_equal false, content.versions.order('version ASC').first.current_version?
  end

  def test_previous_for_first_version_should_return_nil
    content = WikiContent::Version.find_by_page_id_and_version(1, 1)
    assert_nil content.previous
  end

  def test_previous_for_version_should_return_previous_version
    content = WikiContent::Version.find_by_page_id_and_version(1, 3)
    assert_not_nil content.previous
    assert_equal 2, content.previous.version
  end

  def test_previous_for_version_with_gap_should_return_previous_available_version
    WikiContent::Version.find_by_page_id_and_version(1, 2).destroy

    content = WikiContent::Version.find_by_page_id_and_version(1, 3)
    assert_not_nil content.previous
    assert_equal 1, content.previous.version
  end

  def test_next_for_last_version_should_return_nil
    content = WikiContent::Version.find_by_page_id_and_version(1, 3)
    assert_nil content.next
  end

  def test_next_for_version_should_return_next_version
    content = WikiContent::Version.find_by_page_id_and_version(1, 1)
    assert_not_nil content.next
    assert_equal 2, content.next.version
  end

  def test_next_for_version_with_gap_should_return_next_available_version
    WikiContent::Version.find_by_page_id_and_version(1, 2).destroy

    content = WikiContent::Version.find_by_page_id_and_version(1, 1)
    assert_not_nil content.next
    assert_equal 3, content.next.version
  end
end
