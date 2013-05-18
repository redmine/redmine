# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

class WikiTest < ActiveSupport::TestCase
  fixtures :projects, :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions

  def test_create
    wiki = Wiki.new(:project => Project.find(2))
    assert !wiki.save
    assert_equal 1, wiki.errors.count

    wiki.start_page = "Start page"
    assert wiki.save
  end

  def test_update
    @wiki = Wiki.find(1)
    @wiki.start_page = "Another start page"
    assert @wiki.save
    @wiki.reload
    assert_equal "Another start page", @wiki.start_page
  end

  def test_find_page_should_not_be_case_sensitive
    wiki = Wiki.find(1)
    page = WikiPage.find(2)

    assert_equal page, wiki.find_page('Another_page')
    assert_equal page, wiki.find_page('Another page')
    assert_equal page, wiki.find_page('ANOTHER page')
  end

  def test_find_page_with_cyrillic_characters
    wiki = Wiki.find(1)
    page = WikiPage.find(10)
    assert_equal page, wiki.find_page('Этика_менеджмента')
  end

  def test_find_page_with_backslashes
    wiki = Wiki.find(1)
    page = WikiPage.create!(:wiki => wiki, :title => '2009\\02\\09')
    assert_equal page, wiki.find_page('2009\\02\\09')
  end

  def test_find_page_without_redirect
    wiki = Wiki.find(1)
    page = wiki.find_page('Another_page')
    assert_not_nil page
    assert_equal 'Another_page', page.title
    assert_equal false, wiki.page_found_with_redirect?
  end

  def test_find_page_with_redirect
    wiki = Wiki.find(1)
    WikiRedirect.create!(:wiki => wiki, :title => 'Old_title', :redirects_to => 'Another_page')
    page = wiki.find_page('Old_title')
    assert_not_nil page
    assert_equal 'Another_page', page.title
    assert_equal true, wiki.page_found_with_redirect?
  end

  def test_titleize
    ja_test = "\xe3\x83\x86\xe3\x82\xb9\xe3\x83\x88"
    ja_test.force_encoding('UTF-8') if ja_test.respond_to?(:force_encoding)
    assert_equal 'Page_title_with_CAPITALES', Wiki.titleize('page title with CAPITALES')
    assert_equal ja_test, Wiki.titleize(ja_test)
  end

  def test_sidebar_should_return_nil_if_undefined
    @wiki = Wiki.find(1)
    assert_nil @wiki.sidebar
  end

  def test_sidebar_should_return_a_wiki_page_if_defined
    @wiki = Wiki.find(1)
    page = @wiki.pages.new(:title => 'Sidebar')
    page.content = WikiContent.new(:text => 'Side bar content for test_show_with_sidebar')
    page.save!

    assert_kind_of WikiPage, @wiki.sidebar
    assert_equal 'Sidebar', @wiki.sidebar.title
  end
end
