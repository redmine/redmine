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

class WikiHelperTest < Redmine::HelperTest
  include WikiHelper
  include Rails.application.routes.url_helpers

  fixtures :projects, :users,
           :roles, :member_roles, :members,
           :enabled_modules, :wikis, :wiki_pages

  def test_wiki_page_edit_cancel_path_for_new_page_without_parent_should_be_wiki_index
    wiki = Wiki.find(1)
    page = WikiPage.new(:wiki => wiki)
    assert_equal '/projects/ecookbook/wiki/index', wiki_page_edit_cancel_path(page)
  end

  def test_wiki_page_edit_cancel_path_for_new_page_with_parent_should_be_parent
    wiki = Wiki.find(1)
    page = WikiPage.new(:wiki => wiki, :parent => wiki.find_page('Another_page'))
    assert_equal '/projects/ecookbook/wiki/Another_page', wiki_page_edit_cancel_path(page)
  end

  def test_wiki_page_edit_cancel_path_for_existing_page_should_be_the_page
    wiki = Wiki.find(1)
    page = wiki.find_page('Child_1')
    assert_equal '/projects/ecookbook/wiki/Child_1', wiki_page_edit_cancel_path(page)
  end
end
