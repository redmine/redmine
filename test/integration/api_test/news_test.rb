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

class Redmine::ApiTest::NewsTest < Redmine::ApiTest::Base
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :news

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
      post '/projects/1/news.xml',
        :params => payload,
        :headers => {"CONTENT_TYPE" => 'application/xml'}.merge(credentials('jsmith'))
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
      post '/projects/1/news.xml',
        :params => {:news => {:title => ''}},
        :headers => credentials('jsmith')
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
      post '/projects/1/news.json',
        :params => payload,
        :headers => {"CONTENT_TYPE" => 'application/json'}.merge(credentials('jsmith'))
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
      post '/projects/1/news.json',
        :params => {:news => {:title => ''}},
        :headers => credentials('jsmith')
    end
    json = ActiveSupport::JSON.decode(response.body)
    assert json['errors'].include?("Title cannot be blank")
  end

  test "POST /project/:project_id/news.xml with attachment should create a news with attachment" do
    token = xml_upload('test_create_with_attachment', credentials('jsmith'))
    attachment = Attachment.find_by_token(token)

    assert_difference 'News.count' do
      post '/projects/1/news.xml',
        :params => {:news => {:title => 'News XML-API with Attachment',
                              :description => 'desc'},
                    :attachments => [{:token => token, :filename => 'test.txt',
                                      :content_type => 'text/plain'}]},
        :headers => credentials('jsmith')
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
      post '/projects/1/news.xml',
        :params => payload,
        :headers => {"CONTENT_TYPE" => 'application/xml'}.merge(credentials('jsmith'))
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
      post '/projects/1/news.json',
        :params => payload,
        :headers => {"CONTENT_TYPE" => 'application/json'}.merge(credentials('jsmith'))
      assert_response :no_content
    end
    news = News.find_by(:title => 'News JSON-API with attachments')
    assert_equal 2, news.attachments.count
  end
end
