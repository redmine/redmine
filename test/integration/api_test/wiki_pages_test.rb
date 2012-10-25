# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
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

class ApiTest::WikiPagesTest < ActionController::IntegrationTest
  fixtures :projects, :users, :roles, :members, :member_roles,
           :enabled_modules, :wikis, :wiki_pages, :wiki_contents,
           :wiki_content_versions, :attachments

  def setup
    Setting.rest_api_enabled = '1'
  end

  test "GET /projects/:project_id/wiki/index.xml should return wiki pages" do
    get '/projects/ecookbook/wiki/index.xml'
    assert_response :success
    assert_equal 'application/xml', response.content_type
    assert_select 'wiki_pages[type=array]' do
      assert_select 'wiki_page', :count => Wiki.find(1).pages.count
      assert_select 'wiki_page' do
        assert_select 'title', :text => 'CookBook_documentation'
        assert_select 'version', :text => '3'
        assert_select 'created_on'
        assert_select 'updated_on'
      end
    end
  end

  test "GET /projects/:project_id/wiki/:title.xml should return wiki page" do
    get '/projects/ecookbook/wiki/CookBook_documentation.xml'
    assert_response :success
    assert_equal 'application/xml', response.content_type
    assert_select 'wiki_page' do
      assert_select 'title', :text => 'CookBook_documentation'
      assert_select 'version', :text => '3'
      assert_select 'text'
      assert_select 'author'
      assert_select 'created_on'
      assert_select 'updated_on'
    end
  end

  test "GET /projects/:project_id/wiki/:title.xml with unknown title and edit permission should respond with 404" do
    get '/projects/ecookbook/wiki/Invalid_Page.xml', {}, credentials('jsmith')
    assert_response 404
    assert_equal 'application/xml', response.content_type
  end

  test "GET /projects/:project_id/wiki/:title/:version.xml should return wiki page version" do
    get '/projects/ecookbook/wiki/CookBook_documentation/2.xml'
    assert_response :success
    assert_equal 'application/xml', response.content_type
    assert_select 'wiki_page' do
      assert_select 'title', :text => 'CookBook_documentation'
      assert_select 'version', :text => '2'
      assert_select 'text'
      assert_select 'author'
      assert_select 'created_on'
      assert_select 'updated_on'
    end
  end

  test "GET /projects/:project_id/wiki/:title/:version.xml without permission should be denied" do
    Role.anonymous.remove_permission! :view_wiki_edits

    get '/projects/ecookbook/wiki/CookBook_documentation/2.xml'
    assert_response 401
    assert_equal 'application/xml', response.content_type
  end
end
