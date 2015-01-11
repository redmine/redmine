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

class WikiPageTest < ActiveSupport::TestCase
  fixtures :projects, :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions

  def setup
    @wiki = Wiki.find(1)
    @page = @wiki.pages.first
  end

  def test_create
    page = WikiPage.new(:wiki => @wiki)
    assert !page.save
    assert_equal 1, page.errors.count

    page.title = "Page"
    assert page.save
    page.reload
    assert !page.protected?

    @wiki.reload
    assert @wiki.pages.include?(page)
  end

  def test_sidebar_should_be_protected_by_default
    page = @wiki.find_or_new_page('sidebar')
    assert page.new_record?
    assert page.protected?
  end

  def test_find_or_new_page
    page = @wiki.find_or_new_page("CookBook documentation")
    assert_kind_of WikiPage, page
    assert !page.new_record?

    page = @wiki.find_or_new_page("Non existing page")
    assert_kind_of WikiPage, page
    assert page.new_record?
  end

  def test_parent_title
    page = WikiPage.find_by_title('Another_page')
    assert_nil page.parent_title

    page = WikiPage.find_by_title('Page_with_an_inline_image')
    assert_equal 'CookBook documentation', page.parent_title
  end

  def test_assign_parent
    page = WikiPage.find_by_title('Another_page')
    page.parent_title = 'CookBook documentation'
    assert page.save
    page.reload
    assert_equal WikiPage.find_by_title('CookBook_documentation'), page.parent
  end

  def test_unassign_parent
    page = WikiPage.find_by_title('Page_with_an_inline_image')
    page.parent_title = ''
    assert page.save
    page.reload
    assert_nil page.parent
  end

  def test_parent_validation
    page = WikiPage.find_by_title('CookBook_documentation')

    # A page that doesn't exist
    page.parent_title = 'Unknown title'
    assert !page.save
    assert_include I18n.translate('activerecord.errors.messages.invalid'),
                   page.errors[:parent_title]
    # A child page
    page.parent_title = 'Page_with_an_inline_image'
    assert !page.save
    assert_include I18n.translate('activerecord.errors.messages.circular_dependency'),
                   page.errors[:parent_title]
    # The page itself
    page.parent_title = 'CookBook_documentation'
    assert !page.save
    assert_include I18n.translate('activerecord.errors.messages.circular_dependency'),
                   page.errors[:parent_title]
    page.parent_title = 'Another_page'
    assert page.save
  end

  def test_move_child_should_clear_parent
    parent = WikiPage.create!(:wiki_id => 1, :title => 'Parent')
    child = WikiPage.create!(:wiki_id => 1, :title => 'Child', :parent => parent)

    child.wiki_id = 2
    child.save!
    assert_equal nil, child.reload.parent_id
  end

  def test_move_parent_should_move_child_page
    parent = WikiPage.create!(:wiki_id => 1, :title => 'Parent')
    child = WikiPage.create!(:wiki_id => 1, :title => 'Child', :parent => parent)
    parent.reload

    parent.wiki_id = 2
    parent.save!
    assert_equal 2, child.reload.wiki_id
    assert_equal parent, child.parent
  end

  def test_destroy
    page = WikiPage.find(1)
    page.destroy
    assert_nil WikiPage.find_by_id(1)
    # make sure that page content and its history are deleted
    assert_equal 0, WikiContent.where(:page_id => 1).count
    assert_equal 0, WikiContent.versioned_class.where(:page_id => 1).count
  end

  def test_destroy_should_not_nullify_children
    page = WikiPage.find(2)
    child_ids = page.child_ids
    assert child_ids.any?
    page.destroy
    assert_nil WikiPage.find_by_id(2)

    children = WikiPage.where(:id => child_ids)
    assert_equal child_ids.size, children.count
    children.each do |child|
      assert_nil child.parent_id
    end
  end

  def test_updated_on_eager_load
    page = WikiPage.with_updated_on.order('id').first
    assert page.is_a?(WikiPage)
    assert_not_nil page.read_attribute(:updated_on)
    assert_equal Time.gm(2007, 3, 6, 23, 10, 51), page.content.updated_on
    assert_equal page.content.updated_on, page.updated_on
    assert_not_nil page.read_attribute(:version)
  end

  def test_descendants
    page = WikiPage.create!(:wiki => @wiki, :title => 'Parent')
    child1 = WikiPage.create!(:wiki => @wiki, :title => 'Child1', :parent => page)
    child11 = WikiPage.create!(:wiki => @wiki, :title => 'Child11', :parent => child1)
    child111 = WikiPage.create!(:wiki => @wiki, :title => 'Child111', :parent => child11)
    child2 = WikiPage.create!(:wiki => @wiki, :title => 'Child2', :parent => page)

    assert_equal %w(Child1 Child11 Child111 Child2), page.descendants.map(&:title).sort
    assert_equal %w(Child1 Child11 Child111 Child2), page.descendants(nil).map(&:title).sort
    assert_equal %w(Child1 Child11 Child2), page.descendants(2).map(&:title).sort
    assert_equal %w(Child1 Child2), page.descendants(1).map(&:title).sort

    assert_equal %w(Child1 Child11 Child111 Child2 Parent), page.self_and_descendants.map(&:title).sort
    assert_equal %w(Child1 Child11 Child111 Child2 Parent), page.self_and_descendants(nil).map(&:title).sort
    assert_equal %w(Child1 Child11 Child2 Parent), page.self_and_descendants(2).map(&:title).sort
    assert_equal %w(Child1 Child2 Parent), page.self_and_descendants(1).map(&:title).sort
  end

  def test_diff_for_page_with_deleted_version_should_pick_the_previous_available_version
    WikiContent::Version.find_by_page_id_and_version(1, 2).destroy

    page = WikiPage.find(1)
    diff = page.diff(3)
    assert_not_nil diff
    assert_equal 3, diff.content_to.version
    assert_equal 1, diff.content_from.version
  end
end
