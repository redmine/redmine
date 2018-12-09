# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

class Redmine::ApiTest::WikiPagesTest < Redmine::ApiTest::Base
  fixtures :projects, :users, :roles, :members, :member_roles,
           :enabled_modules, :wikis, :wiki_pages, :wiki_contents,
           :wiki_content_versions, :attachments

  test "GET /projects/:project_id/wiki/index.xml should return wiki pages" do
    get '/projects/ecookbook/wiki/index.xml'
    assert_response 200
    assert_equal 'application/xml', response.content_type
    assert_select 'wiki_pages[type=array]' do
      assert_select 'wiki_page', :count => Wiki.find(1).pages.count
      assert_select 'wiki_page' do
        assert_select 'title', :text => 'CookBook_documentation'
        assert_select 'version', :text => '3'
        assert_select 'created_on'
        assert_select 'updated_on'
      end
      assert_select 'wiki_page' do
        assert_select 'title', :text => 'Page_with_an_inline_image'
        assert_select 'parent[title=?]', 'CookBook_documentation'
      end
    end
  end

  test "GET /projects/:project_id/wiki/:title.xml should return wiki page" do
    get '/projects/ecookbook/wiki/CookBook_documentation.xml'
    assert_response 200
    assert_equal 'application/xml', response.content_type
    assert_select 'wiki_page' do
      assert_select 'title', :text => 'CookBook_documentation'
      assert_select 'version', :text => '3'
      assert_select 'text'
      assert_select 'author'
      assert_select 'comments'
      assert_select 'created_on'
      assert_select 'updated_on'
    end
  end

  test "GET /projects/:project_id/wiki/:title.xml?include=attachments should include attachments" do
    get '/projects/ecookbook/wiki/Page_with_an_inline_image.xml?include=attachments'
    assert_response 200
    assert_equal 'application/xml', response.content_type
    assert_select 'wiki_page' do
      assert_select 'title', :text => 'Page_with_an_inline_image'
      assert_select 'attachments[type=array]' do
        assert_select 'attachment' do
          assert_select 'id', :text => '3'
          assert_select 'filename', :text => 'logo.gif'
        end
      end
    end
  end

  test "GET /projects/:project_id/wiki/:title.xml with unknown title and edit permission should respond with 404" do
    get '/projects/ecookbook/wiki/Invalid_Page.xml', :headers => credentials('jsmith')
    assert_response 404
    assert_equal 'application/xml', response.content_type
  end

  test "GET /projects/:project_id/wiki/:title/:version.xml should return wiki page version" do
    get '/projects/ecookbook/wiki/CookBook_documentation/2.xml'
    assert_response 200
    assert_equal 'application/xml', response.content_type
    assert_select 'wiki_page' do
      assert_select 'title', :text => 'CookBook_documentation'
      assert_select 'version', :text => '2'
      assert_select 'text'
      assert_select 'author'
      assert_select 'comments', :text => 'Small update'
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

  test "PUT /projects/:project_id/wiki/:title.xml should update wiki page" do
    assert_no_difference 'WikiPage.count' do
      assert_difference 'WikiContent::Version.count' do
        put '/projects/ecookbook/wiki/CookBook_documentation.xml',
          :params => {:wiki_page => {:text => 'New content from API', :comments => 'API update'}},
          :headers => credentials('jsmith')
        assert_response 200
      end
    end

    page = WikiPage.find(1)
    assert_equal 'New content from API', page.content.text
    assert_equal 4, page.content.version
    assert_equal 'API update', page.content.comments
    assert_equal 'jsmith', page.content.author.login
  end

  test "PUT /projects/:project_id/wiki/:title.xml with current versino should update wiki page" do
    assert_no_difference 'WikiPage.count' do
      assert_difference 'WikiContent::Version.count' do
        put '/projects/ecookbook/wiki/CookBook_documentation.xml',
          :params => {:wiki_page => {:text => 'New content from API', :comments => 'API update', :version => '3'}},
          :headers => credentials('jsmith')
        assert_response 200
      end
    end

    page = WikiPage.find(1)
    assert_equal 'New content from API', page.content.text
    assert_equal 4, page.content.version
    assert_equal 'API update', page.content.comments
    assert_equal 'jsmith', page.content.author.login
  end

  test "PUT /projects/:project_id/wiki/:title.xml with stale version should respond with 409" do
    assert_no_difference 'WikiPage.count' do
      assert_no_difference 'WikiContent::Version.count' do
        put '/projects/ecookbook/wiki/CookBook_documentation.xml',
          :params => {:wiki_page => {:text => 'New content from API', :comments => 'API update', :version => '2'}},
          :headers => credentials('jsmith')
        assert_response 409
      end
    end
  end

  test "PUT /projects/:project_id/wiki/:title.xml should create the page if it does not exist" do
    assert_difference 'WikiPage.count' do
      assert_difference 'WikiContent::Version.count' do
        put '/projects/ecookbook/wiki/New_page_from_API.xml',
          :params => {:wiki_page => {:text => 'New content from API', :comments => 'API create'}},
          :headers => credentials('jsmith')
        assert_response 201
      end
    end

    page = WikiPage.order('id DESC').first
    assert_equal 'New_page_from_API', page.title
    assert_equal 'New content from API', page.content.text
    assert_equal 1, page.content.version
    assert_equal 'API create', page.content.comments
    assert_equal 'jsmith', page.content.author.login
    assert_nil page.parent
  end

  test "PUT /projects/:project_id/wiki/:title.xml with attachment" do
    set_tmp_attachments_directory
    attachment = Attachment.create!(:file => uploaded_test_file("testfile.txt", "text/plain"), :author_id => 2)
    assert_difference 'WikiPage.count' do
      assert_difference 'WikiContent::Version.count' do
        put '/projects/ecookbook/wiki/New_page_from_API.xml',
            :params => {:wiki_page => {:text => 'New content from API with Attachments', :comments => 'API create with Attachments',
                            :uploads => [:token => attachment.token, :filename => 'testfile.txt', :content_type => "text/plain"]}},
            :headers => credentials('jsmith')
        assert_response 201
      end
    end

    page = WikiPage.order('id DESC').first
    assert_equal 'New_page_from_API', page.title
    assert_include attachment, page.attachments
    assert_equal attachment.filename, page.attachments.first.filename
  end

  test "PUT /projects/:project_id/wiki/:title.xml with parent" do
    assert_difference 'WikiPage.count' do
      assert_difference 'WikiContent::Version.count' do
        put '/projects/ecookbook/wiki/New_subpage_from_API.xml',
          :params => {:wiki_page => {:parent_title => 'CookBook_documentation', :text => 'New content from API', :comments => 'API create'}},
          :headers => credentials('jsmith')
        assert_response 201
      end
    end

    page = WikiPage.order('id DESC').first
    assert_equal 'New_subpage_from_API', page.title
    assert_equal WikiPage.find(1), page.parent
  end

  test "DELETE /projects/:project_id/wiki/:title.xml should destroy the page" do
    assert_difference 'WikiPage.count', -1 do
      delete '/projects/ecookbook/wiki/CookBook_documentation.xml', :headers => credentials('jsmith')
      assert_response 200
    end

    assert_nil WikiPage.find_by_id(1)
  end
end
