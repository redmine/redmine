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

require_relative '../../test_helper'

class Redmine::ApiTest::NewsTest < Redmine::ApiTest::Base
  test "GET /news.xml should return news" do
    get '/news.xml'

    assert_select 'news[type=array] news id', :text => '2'
  end

  test "GET /news.json should return news" do
    get '/news.json'

    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert_kind_of Array, json['news']
    assert_kind_of Hash, json['news'].first
    assert_equal 2, json['news'].first['id']
  end

  test "GET /projects/:project_id/news.xml should return news" do
    get '/projects/ecookbook/news.xml'

    assert_select 'news[type=array] news id', :text => '2'
  end

  test "GET /projects/:project_id/news.json should return news" do
    get '/projects/ecookbook/news.json'

    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert_kind_of Array, json['news']
    assert_kind_of Hash, json['news'].first
    assert_equal 2, json['news'].first['id']
  end

  test "GET /news/:id.xml" do
    get "/news/1.xml"
    assert_response :success
    assert_equal 'application/xml', response.media_type
    assert_select 'news' do
      assert_select 'id', 1
      assert_select "project[id=1][name=\"eCookbook\"]"
      assert_select "author[id=2][name=\"John Smith\"]"
      assert_select 'title', 'eCookbook first release !'
      assert_select 'summary', 'First version was released...'
      assert_select 'description', "eCookbook 1.0 has been released.\n\nVisit http://ecookbook.somenet.foo/"
      assert_select 'created_on', News.find(1).created_on.iso8601
    end
  end

  test "GET /news/:id.json" do
    get "/news/1.json"
    assert_response :success
    assert_equal 'application/json', response.media_type
    json = ActiveSupport::JSON.decode(response.body)
    assert_equal 1, json['news']['id']
  end

  test "GET /news/:id.xml with attachments" do
    news = News.find(1)
    attachment = Attachment.first
    attachment.container = news
    attachment.save!

    get "/news/1.xml?include=attachments"
    assert_select 'news attachments[type=array]' do
      assert_select 'attachment id', :text => '1' do
        assert_select '~ filename', :text => 'error281.txt'
        assert_select '~ content_url', :text => 'http://www.example.com/attachments/download/1/error281.txt'
      end
    end
  end

  test "GET /news/:id.xml with comments" do
    get "/news/1.xml?include=comments"
    assert_select 'news comments[type=array]' do
      assert_select 'comment', 2
      assert_select 'comment[id=1]' do
        assert_select 'author[id=1][name="Redmine Admin"]'
        assert_select 'content', :text => 'my first comment'
      end
      assert_select 'comment[id=2]' do
        assert_select 'author[id=2][name="John Smith"]'
        assert_select 'content', :text => 'This is an other comment'
      end
    end
  end

  test "POST /project/:project_id/news.xml should create a news with the attributes" do
    payload = <<~XML
      <?xml version="1.0" encoding="UTF-8" ?>
      <news>
        <title>NewsXmlApiTest</title>
        <summary>News XML-API Test</summary>
        <description>This is the description</description>
      </news>
    XML
    assert_difference('News.count') do
      post(
        '/projects/1/news.xml',
        :params => payload,
        :headers => {"CONTENT_TYPE" => 'application/xml'}.merge(credentials('jsmith')))
    end
    news = News.find_by(:title => 'NewsXmlApiTest')
    assert_not_nil news
    assert_equal 'News XML-API Test', news.summary
    assert_equal 'This is the description', news.description
    assert_equal User.find_by_login('jsmith'), news.author
    assert_equal Project.find(1), news.project
    assert_response :no_content
  end

  test "POST /project/:project_id/news.xml with failure should return errors" do
    assert_no_difference('News.count') do
      post(
        '/projects/1/news.xml',
        :params => {:news => {:title => ''}},
        :headers => credentials('jsmith'))
    end
    assert_select 'errors error', :text => "Title cannot be blank"
  end

  test "POST /project/:project_id/news.json should create a news with the attributes" do
    payload = <<~JSON
      {
        "news": {
          "title": "NewsJsonApiTest",
          "summary": "News JSON-API Test",
          "description": "This is the description"
        }
      }
    JSON
    assert_difference('News.count') do
      post(
        '/projects/1/news.json',
        :params => payload,
        :headers => {"CONTENT_TYPE" => 'application/json'}.merge(credentials('jsmith')))
    end
    news = News.find_by(:title => 'NewsJsonApiTest')
    assert_not_nil news
    assert_equal 'News JSON-API Test', news.summary
    assert_equal 'This is the description', news.description
    assert_equal User.find_by_login('jsmith'), news.author
    assert_equal Project.find(1), news.project
    assert_response :no_content
  end

  test "POST /project/:project_id/news.json with failure should return errors" do
    assert_no_difference('News.count') do
      post(
        '/projects/1/news.json',
        :params => {:news => {:title => ''}},
        :headers => credentials('jsmith'))
    end
    json = ActiveSupport::JSON.decode(response.body)
    assert json['errors'].include?("Title cannot be blank")
  end

  test "POST /project/:project_id/news.xml with attachment should create a news with attachment" do
    token = xml_upload('test_create_with_attachment', credentials('jsmith'))
    attachment = Attachment.find_by_token(token)
    assert_difference 'News.count' do
      post(
        '/projects/1/news.xml',
        :params => {:news => {:title => 'News XML-API with Attachment',
                              :description => 'desc'},
                    :attachments => [{:token => token, :filename => 'test.txt',
                                      :content_type => 'text/plain'}]},
        :headers => credentials('jsmith'))
      assert_response :no_content
    end
    news = News.find_by(:title => 'News XML-API with Attachment')
    assert_equal attachment, news.attachments.first

    attachment.reload
    assert_equal 'test.txt', attachment.filename
    assert_equal 'text/plain', attachment.content_type
    assert_equal 'test_create_with_attachment'.size, attachment.filesize
    assert_equal 2, attachment.author_id
  end

  test "POST /project/:project_id/news.xml with multiple attachment should create a news with attachments" do
    token1 = xml_upload('File content 1', credentials('jsmith'))
    token2 = xml_upload('File content 2', credentials('jsmith'))
    payload = <<~XML
      <?xml version="1.0" encoding="UTF-8" ?>
      <news>
        <title>News XML-API with attachments</title>
        <description>News with multiple attachments</description>
        <uploads type="array">
          <upload>
            <token>#{token1}</token>
            <filename>test1.txt</filename>
          </upload>
          <upload>
            <token>#{token2}</token>
            <filename>test2.txt</filename>
          </upload>
        </uploads>
      </news>
    XML
    assert_difference('News.count') do
      post(
        '/projects/1/news.xml',
        :params => payload,
        :headers => {"CONTENT_TYPE" => 'application/xml'}.merge(credentials('jsmith')))
      assert_response :no_content
    end
    news = News.find_by(:title => 'News XML-API with attachments')
    assert_equal 2, news.attachments.count
  end

  test "POST /project/:project_id/news.json with multiple attachment should create a news with attachments" do
    token1 = json_upload('File content 1', credentials('jsmith'))
    token2 = json_upload('File content 2', credentials('jsmith'))
    payload = <<~JSON
      {
        "news": {
          "title": "News JSON-API with attachments",
          "description": "News with multiple attachments",
          "uploads": [
            {"token": "#{token1}", "filename": "test1.txt"},
            {"token": "#{token2}", "filename": "test2.txt"}
          ]
        }
      }
    JSON
    assert_difference('News.count') do
      post(
        '/projects/1/news.json',
        :params => payload,
        :headers => {"CONTENT_TYPE" => 'application/json'}.merge(credentials('jsmith')))
      assert_response :no_content
    end
    news = News.find_by(:title => 'News JSON-API with attachments')
    assert_equal 2, news.attachments.count
  end

  test "PUT /news/:id.xml" do
    payload = <<~XML
      <?xml version="1.0" encoding="UTF-8" ?>
      <news>
        <title>NewsUpdateXmlApiTest</title>
        <summary>News Update XML-API Test</summary>
        <description>update description via xml api</description>
      </news>
    XML
    put(
      '/news/1.xml',
      :params => payload,
      :headers => {"CONTENT_TYPE" => 'application/xml'}.merge(credentials('jsmith')))
    news = News.find(1)
    assert_equal 'NewsUpdateXmlApiTest', news.title
    assert_equal 'News Update XML-API Test', news.summary
    assert_equal 'update description via xml api', news.description
  end

  test "PUT /news/:id.json" do
    payload = <<~JSON
      {
        "news": {
          "title": "NewsUpdateJsonApiTest",
          "summary": "News Update JSON-API Test",
          "description": "update description via json api"
        }
      }
    JSON
    put(
      '/news/1.json',
      :params => payload,
      :headers => {"CONTENT_TYPE" => 'application/json'}.merge(credentials('jsmith')))
    news = News.find(1)
    assert_equal 'NewsUpdateJsonApiTest', news.title
    assert_equal 'News Update JSON-API Test', news.summary
    assert_equal 'update description via json api', news.description
  end

  test "PUT /news/:id.xml with failed update" do
    put(
      '/news/1.xml',
      :params => {:news => {:title => ''}},
      :headers => credentials('jsmith'))
    assert_response :unprocessable_content
    assert_select 'errors error', :text => "Title cannot be blank"
  end

  test "PUT /news/:id.json with failed update" do
    put(
      '/news/1.json',
      :params => {:news => {:title => ''}},
      :headers => credentials('jsmith'))
    assert_response :unprocessable_content
    json = ActiveSupport::JSON.decode(response.body)
    assert json['errors'].include?("Title cannot be blank")
  end

  test "PUT /news/:id.xml with multiple attachment should update a news with attachments" do
    token1 = xml_upload('File content 1', credentials('jsmith'))
    token2 = xml_upload('File content 2', credentials('jsmith'))
    payload = <<~XML
      <?xml version="1.0" encoding="UTF-8" ?>
      <news>
        <title>News Update XML-API with attachments</title>
        <uploads type="array">
          <upload>
            <token>#{token1}</token>
            <filename>test1.txt</filename>
          </upload>
          <upload>
            <token>#{token2}</token>
            <filename>test2.txt</filename>
          </upload>
        </uploads>
      </news>
    XML
    put(
      '/news/1.xml',
      :params => payload,
      :headers => {"CONTENT_TYPE" => 'application/xml'}.merge(credentials('jsmith')))
    assert_response :no_content
    news = News.find_by(:title => 'News Update XML-API with attachments')
    assert_equal 2, news.attachments.count
  end

  test "PUT /news/:id.json with multiple attachment should update a news with attachments" do
    token1 = json_upload('File content 1', credentials('jsmith'))
    token2 = json_upload('File content 2', credentials('jsmith'))
    payload = <<~JSON
      {
        "news": {
          "title": "News Update JSON-API with attachments",
          "uploads": [
            {"token": "#{token1}", "filename": "test1.txt"},
            {"token": "#{token2}", "filename": "test2.txt"}
          ]
        }
      }
    JSON
    put(
      '/news/1.json',
      :params => payload,
      :headers => {"CONTENT_TYPE" => 'application/json'}.merge(credentials('jsmith')))
    assert_response :no_content
    news = News.find_by(:title => 'News Update JSON-API with attachments')
    assert_equal 2, news.attachments.count
  end

  test "DELETE /news/:id.xml" do
    assert_difference('News.count', -1) do
      delete '/news/1.xml', :headers => credentials('jsmith')

      assert_response :no_content
      assert_equal '', response.body
    end
    assert_nil News.find_by_id(1)
  end

  test "DELETE /news/:id.json" do
    assert_difference('News.count', -1) do
      delete '/news/1.json', :headers => credentials('jsmith')

      assert_response :no_content
      assert_equal '', response.body
    end
    assert_nil News.find_by_id(6)
  end
end
