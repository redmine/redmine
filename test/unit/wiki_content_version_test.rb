# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class WikiContentVersionTest < ActiveSupport::TestCase
  fixtures :projects, :users, :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions

  def setup
  end

  def test_destroy
    v = WikiContent::Version.find(2)

    assert_difference 'WikiContent::Version.count', -1 do
      v.destroy
    end
  end

  def test_destroy_last_version_should_revert_content
    v = WikiContent::Version.find(3)

    assert_no_difference 'WikiPage.count' do
      assert_no_difference 'WikiContent.count' do
        assert_difference 'WikiContent::Version.count', -1 do
          assert v.destroy
        end
      end
    end
    c = WikiContent.find(1)
    v = c.versions.last
    assert_equal 2, c.version
    assert_equal v.version, c.version
    assert_equal v.comments, c.comments
    assert_equal v.text, c.text
    assert_equal v.author, c.author
    assert_equal v.updated_on, c.updated_on
  end

  def test_destroy_all_versions_should_delete_page
    WikiContent::Version.find(1).destroy
    WikiContent::Version.find(2).destroy
    v = WikiContent::Version.find(3)

    assert_difference 'WikiPage.count', -1 do
      assert_difference 'WikiContent.count', -1 do
        assert_difference 'WikiContent::Version.count', -1 do
          assert v.destroy
        end
      end
    end
    assert_nil WikiPage.find_by_id(1)
  end
end
