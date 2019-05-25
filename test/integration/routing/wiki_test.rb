# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

require File.expand_path('../../../test_helper', __FILE__)

class RoutingWikiTest < Redmine::RoutingTest
  def test_wiki
    should_route 'GET /projects/foo/wiki' => 'wiki#show', :project_id => 'foo'
    should_route 'GET /projects/foo/wiki/index' => 'wiki#index', :project_id => 'foo'
    should_route 'GET /projects/foo/wiki/date_index' => 'wiki#date_index', :project_id => 'foo'
    should_route 'GET /projects/foo/wiki/export' => 'wiki#export', :project_id => 'foo'
    should_route 'GET /projects/foo/wiki/export.pdf' => 'wiki#export', :project_id => 'foo', :format => 'pdf'
  end

  def test_wiki_pages
    should_route 'GET /projects/foo/wiki/page' => 'wiki#show', :project_id => 'foo', :id => 'page'
    should_route 'GET /projects/foo/wiki/page.pdf' => 'wiki#show', :project_id => 'foo', :id => 'page', :format => 'pdf'

    should_route 'GET /projects/foo/wiki/new' => 'wiki#new', :project_id => 'foo'
    should_route 'POST /projects/foo/wiki/new' => 'wiki#new', :project_id => 'foo'

    should_route 'GET /projects/foo/wiki/page/edit' => 'wiki#edit', :project_id => 'foo', :id => 'page'
    should_route 'PUT /projects/foo/wiki/page' => 'wiki#update', :project_id => 'foo', :id => 'page'
    should_route 'DELETE /projects/foo/wiki/page' => 'wiki#destroy', :project_id => 'foo', :id => 'page'

    should_route 'GET /projects/foo/wiki/page/history' => 'wiki#history', :project_id => 'foo', :id => 'page'
    should_route 'GET /projects/foo/wiki/page/diff' => 'wiki#diff', :project_id => 'foo', :id => 'page'
    should_route 'GET /projects/foo/wiki/page/rename' => 'wiki#rename', :project_id => 'foo', :id => 'page'
    should_route 'POST /projects/foo/wiki/page/rename' => 'wiki#rename', :project_id => 'foo', :id => 'page'
    should_route 'POST /projects/foo/wiki/page/protect' => 'wiki#protect', :project_id => 'foo', :id => 'page'
    should_route 'POST /projects/foo/wiki/page/add_attachment' => 'wiki#add_attachment', :project_id => 'foo', :id => 'page'

    should_route 'POST /projects/foo/wiki/page/preview' => 'wiki#preview', :project_id => 'foo', :id => 'page'
    should_route 'PUT /projects/foo/wiki/page/preview' => 'wiki#preview', :project_id => 'foo', :id => 'page'

    # Make sure we don't route wiki page sub-uris to let plugins handle them
    assert_raise(Minitest::Assertion) do
      assert_recognizes({}, {:method => 'get', :path => "/projects/foo/wiki/page/whatever"})
    end
  end

  def test_wiki_page_versions
    should_route 'GET /projects/foo/wiki/page/2' => 'wiki#show', :project_id => 'foo', :id => 'page', :version => '2'
    should_route 'GET /projects/foo/wiki/page/2/diff' => 'wiki#diff', :project_id => 'foo', :id => 'page', :version => '2'
    should_route 'GET /projects/foo/wiki/page/2/annotate' => 'wiki#annotate', :project_id => 'foo', :id => 'page', :version => '2'
    should_route 'DELETE /projects/foo/wiki/page/2' => 'wiki#destroy_version', :project_id => 'foo', :id => 'page', :version => '2'
  end
end
