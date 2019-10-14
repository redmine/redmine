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

class Redmine::ApiTest::AttachmentsTest < Redmine::ApiTest::Base
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :attachments

  def setup
    super
    set_fixtures_attachments_directory
  end

  def teardown
    super
    set_tmp_attachments_directory
  end

  test "GET /attachments/:id.xml should return the attachment" do
    get '/attachments/7.xml', :headers => credentials('jsmith')
    assert_response :success
    assert_equal 'application/xml', @response.content_type
    assert_select 'attachment id', :text => '7' do
      assert_select '~ filename', :text => 'archive.zip'
      assert_select '~ content_url', :text => 'http://www.example.com/attachments/download/7/archive.zip'
    end
  end

  test "GET /attachments/:id.xml for image should include thumbnail_url" do
    get '/attachments/16.xml', :headers => credentials('jsmith')
    assert_response :success
    assert_equal 'application/xml', @response.content_type
    assert_select 'attachment id:contains(16)' do
      assert_select '~ thumbnail_url', :text => 'http://www.example.com/attachments/thumbnail/16'
    end
  end

  test "GET /attachments/:id.xml should deny access without credentials" do
    get '/attachments/7.xml'
    assert_response 401
  end

  test "GET /attachments/download/:id/:filename should return the attachment content" do
    get '/attachments/download/7/archive.zip', :headers => credentials('jsmith')
    assert_response :success
    assert_equal 'application/zip', @response.content_type
  end

  test "GET /attachments/download/:id/:filename should deny access without credentials" do
    get '/attachments/download/7/archive.zip'
    assert_response 401
  end

  test "GET /attachments/thumbnail/:id should return the thumbnail" do
    skip unless convert_installed?
    get '/attachments/thumbnail/16', :headers => credentials('jsmith')
    assert_response :success
  end

  test "DELETE /attachments/:id.xml should return ok and delete Attachment" do
    assert_difference 'Attachment.count', -1 do
      delete '/attachments/7.xml', :headers => credentials('jsmith')
      assert_response :no_content
      assert_equal '', response.body
    end
    assert_nil Attachment.find_by_id(7)
  end

  test "DELETE /attachments/:id.json should return ok and delete Attachment" do
    assert_difference 'Attachment.count', -1 do
      delete '/attachments/7.json', :headers => credentials('jsmith')
      assert_response :no_content
      assert_equal '', response.body
    end
    assert_nil Attachment.find_by_id(7)
  end

  test "PATCH /attachments/:id.json should update the attachment" do
    patch '/attachments/7.json',
      :params => {:attachment => {:filename => 'renamed.zip', :description => 'updated'}},
      :headers => credentials('jsmith')

    assert_response :no_content
    assert_nil response.content_type
    attachment = Attachment.find(7)
    assert_equal 'renamed.zip', attachment.filename
    assert_equal 'updated', attachment.description
  end

  test "PATCH /attachments/:id.json with failure should return the errors" do
    patch '/attachments/7.json',
      :params => {:attachment => {:filename => '', :description => 'updated'}},
      :headers => credentials('jsmith')

    assert_response 422
    assert_equal 'application/json', response.content_type
    json = ActiveSupport::JSON.decode(response.body)
    assert_include "File cannot be blank", json['errors']
  end

  test "POST /uploads.xml should return the token" do
    set_tmp_attachments_directory
    assert_difference 'Attachment.count' do
      post '/uploads.xml', :headers => {
          "RAW_POST_DATA" => 'File content',
          "CONTENT_TYPE" => 'application/octet-stream'
        }.merge(credentials('jsmith'))
      assert_response :created
      assert_equal 'application/xml', response.content_type
    end

    xml = Hash.from_xml(response.body)
    assert_kind_of Hash, xml['upload']
    token = xml['upload']['token']
    assert_not_nil token
    attachment_id = xml['upload']['id']
    assert_not_nil attachment_id

    attachment = Attachment.order('id DESC').first
    assert_equal token, attachment.token
    assert_equal attachment_id, attachment.id.to_s
    assert_nil attachment.container
    assert_equal 2, attachment.author_id
    assert_equal 'File content'.size, attachment.filesize
    assert attachment.content_type.blank?
    assert attachment.filename.present?
    assert_match %r{\d+_[0-9a-z]+}, attachment.diskfile
    assert File.exist?(attachment.diskfile)
    assert_equal 'File content', File.read(attachment.diskfile)
  end

  test "POST /uploads.json should return the token" do
    set_tmp_attachments_directory
    assert_difference 'Attachment.count' do
      post '/uploads.json', :headers => {
          "RAW_POST_DATA" => 'File content',
          "CONTENT_TYPE" => 'application/octet-stream'
        }.merge(credentials('jsmith'))
      assert_response :created
      assert_equal 'application/json', response.content_type
    end

    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json['upload']
    token = json['upload']['token']
    assert_not_nil token

    attachment = Attachment.order('id DESC').first
    assert_equal token, attachment.token
  end

  test "POST /uploads.xml should accept :filename param as the attachment filename" do
    set_tmp_attachments_directory
    assert_difference 'Attachment.count' do
      post '/uploads.xml?filename=test.txt', :headers => {
          "RAW_POST_DATA" => 'File content',
          "CONTENT_TYPE" => 'application/octet-stream'
        }.merge(credentials('jsmith'))
      assert_response :created
    end

    attachment = Attachment.order('id DESC').first
    assert_equal 'test.txt', attachment.filename
    assert_match /_test\.txt$/, attachment.diskfile
  end

  test "POST /uploads.xml should not accept other content types" do
    set_tmp_attachments_directory
    assert_no_difference 'Attachment.count' do
      post '/uploads.xml', :headers => {
          "RAW_POST_DATA" => 'PNG DATA',
          "CONTENT_TYPE" => 'image/png'
        }.merge(credentials('jsmith'))
      assert_response 406
    end
  end

  test "POST /uploads.xml should return errors if file is too big" do
    set_tmp_attachments_directory
    with_settings :attachment_max_size => 1 do
      assert_no_difference 'Attachment.count' do
        post '/uploads.xml', :headers => {
            "RAW_POST_DATA" => ('x' * 2048),
            "CONTENT_TYPE" => 'application/octet-stream'
          }.merge(credentials('jsmith'))
        assert_response 422
        assert_select 'error', :text => /exceeds the maximum allowed file size/
      end
    end
  end

  test "POST /uploads.json should create an empty file and return a valid token" do
    set_tmp_attachments_directory
    assert_difference 'Attachment.count' do
      post '/uploads.json', :headers => {
          "CONTENT_TYPE" => 'application/octet-stream'
        }.merge(credentials('jsmith'))
      assert_response :created
    end
    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json['upload']
    token = json['upload']['token']
    assert token.present?
    assert attachment = Attachment.find_by_token(token)
    assert_equal 0, attachment.filesize
    assert attachment.digest.present?
    assert File.exist? attachment.diskfile
  end
end
