# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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

class ApiTest::AttachmentsTest < ActionController::IntegrationTest
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :workflows,
           :attachments

  def setup
    Setting.rest_api_enabled = '1'
    Attachment.storage_path = "#{Rails.root}/test/fixtures/files"
  end

  context "/attachments/:id" do
    context "GET" do
      should "return the attachment" do
        get '/attachments/7.xml', {}, :authorization => credentials('jsmith')
        assert_response :success
        assert_equal 'application/xml', @response.content_type
        assert_tag :tag => 'attachment',
          :child => {
            :tag => 'id',
            :content => '7',
            :sibling => {
              :tag => 'filename',
              :content => 'archive.zip',
              :sibling => {
                :tag => 'content_url',
                :content => 'http://www.example.com/attachments/download/7/archive.zip'
              }
            }
          }
      end

      should "deny access without credentials" do
        get '/attachments/7.xml'
        assert_response 401
        set_tmp_attachments_directory
      end
    end
  end

  context "/attachments/download/:id/:filename" do
    context "GET" do
      should "return the attachment content" do
        get '/attachments/download/7/archive.zip',
            {}, :authorization => credentials('jsmith')
        assert_response :success
        assert_equal 'application/octet-stream', @response.content_type
        set_tmp_attachments_directory
      end

      should "deny access without credentials" do
        get '/attachments/download/7/archive.zip'
        assert_response 302
        set_tmp_attachments_directory
      end
    end
  end

  def credentials(user, password=nil)
    ActionController::HttpAuthentication::Basic.encode_credentials(user, password || user)
  end
end
