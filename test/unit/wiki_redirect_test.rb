# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

class WikiRedirectTest < ActiveSupport::TestCase
  fixtures :projects, :wikis, :wiki_pages

  def setup
    User.current = nil
    @wiki = Wiki.find(1)
    @original = WikiPage.create(:wiki => @wiki, :title => 'Original title')
  end

  def test_create_redirect_on_rename
    @original.title = 'New title'
    @original.save!

    redirect = @wiki.redirects.find_by_title('Original_title')
    assert_not_nil redirect
    assert_equal 1, redirect.redirects_to_wiki_id
    assert_equal 'New_title', redirect.redirects_to
    assert_equal @original, redirect.target_page
  end

  def test_create_redirect_on_move
    @original.wiki_id = 2
    @original.save!

    redirect = @wiki.redirects.find_by_title('Original_title')
    assert_not_nil redirect
    assert_equal 2, redirect.redirects_to_wiki_id
    assert_equal 'Original_title', redirect.redirects_to
    assert_equal @original, redirect.target_page
  end

  def test_create_redirect_on_rename_and_move
    @original.title = 'New title'
    @original.wiki_id = 2
    @original.save!

    redirect = @wiki.redirects.find_by_title('Original_title')
    assert_not_nil redirect
    assert_equal 2, redirect.redirects_to_wiki_id
    assert_equal 'New_title', redirect.redirects_to
    assert_equal @original, redirect.target_page
  end

  def test_update_redirect
    # create a redirect that point to this page
    assert WikiRedirect.create(:wiki => @wiki, :title => 'An_old_page', :redirects_to => 'Original_title')

    @original.title = 'New title'
    @original.save
    # make sure the old page now points to the new page
    assert_equal 'New_title', @wiki.find_page('An old page').title
  end

  def test_reverse_rename
    # create a redirect that point to this page
    assert WikiRedirect.create(:wiki => @wiki, :title => 'An_old_page', :redirects_to => 'Original_title')

    @original.title = 'An old page'
    @original.save
    assert !@wiki.redirects.find_by_title_and_redirects_to('An_old_page', 'An_old_page')
    assert @wiki.redirects.find_by_title_and_redirects_to('Original_title', 'An_old_page')
  end

  def test_rename_to_already_redirected
    assert WikiRedirect.create(:wiki => @wiki, :title => 'An_old_page', :redirects_to => 'Other_page')

    @original.title = 'An old page'
    @original.save
    # this redirect have to be removed since 'An old page' page now exists
    assert !@wiki.redirects.find_by_title_and_redirects_to('An_old_page', 'Other_page')
  end

  def test_redirects_removed_when_deleting_page
    assert WikiRedirect.create(:wiki => @wiki, :title => 'An_old_page', :redirects_to => 'Original_title')

    @original.destroy
    assert_not @wiki.redirects.exists?
  end
end
