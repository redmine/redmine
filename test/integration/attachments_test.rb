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

class AttachmentsTest < Redmine::IntegrationTest
  fixtures :projects, :enabled_modules,
           :users, :roles, :members, :member_roles,
           :trackers, :projects_trackers,
           :issue_statuses, :enumerations

  def test_upload_should_set_default_content_type
    log_user('jsmith', 'jsmith')
    assert_difference 'Attachment.count' do
      post "/uploads.js?attachment_id=1&filename=foo.txt", "File content", {"CONTENT_TYPE" => 'application/octet-stream'}
      assert_response :success
    end
    attachment = Attachment.order(:id => :desc).first
    assert_equal 'text/plain', attachment.content_type
  end

  def test_upload_should_accept_content_type_param
    log_user('jsmith', 'jsmith')
    assert_difference 'Attachment.count' do
      post "/uploads.js?attachment_id=1&filename=foo&content_type=image/jpeg", "File content", {"CONTENT_TYPE" => 'application/octet-stream'}
      assert_response :success
    end
    attachment = Attachment.order(:id => :desc).first
    assert_equal 'image/jpeg', attachment.content_type
  end

  def test_upload_as_js_and_attach_to_an_issue
    log_user('jsmith', 'jsmith')

    token = ajax_upload('myupload.txt', 'File content')

    assert_difference 'Issue.count' do
      post '/projects/ecookbook/issues', {
          :issue => {:tracker_id => 1, :subject => 'Issue with upload'},
          :attachments => {'1' => {:filename => 'myupload.txt', :description => 'My uploaded file', :token => token}}
        }
      assert_response 302
    end

    issue = Issue.order('id DESC').first
    assert_equal 'Issue with upload', issue.subject
    assert_equal 1, issue.attachments.count

    attachment = issue.attachments.first
    assert_equal 'myupload.txt', attachment.filename
    assert_equal 'My uploaded file', attachment.description
    assert_equal 'File content'.length, attachment.filesize
  end

  def test_upload_as_js_and_preview_as_inline_attachment
    log_user('jsmith', 'jsmith')

    token = ajax_upload('myupload.jpg', 'JPEG content')

    post '/issues/preview/new/ecookbook', {
        :issue => {:tracker_id => 1, :description => 'Inline upload: !myupload.jpg!'},
        :attachments => {'1' => {:filename => 'myupload.jpg', :description => 'My uploaded file', :token => token}}
      }
    assert_response :success

    attachment_path = response.body.match(%r{<img src="(/attachments/download/\d+/myupload.jpg)"})[1]
    assert_not_nil token, "No attachment path found in response:\n#{response.body}"

    get attachment_path
    assert_response :success
    assert_equal 'JPEG content', response.body
  end

  def test_upload_and_resubmit_after_validation_failure
    log_user('jsmith', 'jsmith')

    token = ajax_upload('myupload.txt', 'File content')

    assert_no_difference 'Issue.count' do
      post '/projects/ecookbook/issues', {
          :issue => {:tracker_id => 1, :subject => ''},
          :attachments => {'1' => {:filename => 'myupload.txt', :description => 'My uploaded file', :token => token}}
        }
      assert_response :success
    end
    assert_select 'input[type=hidden][name=?][value=?]', 'attachments[p0][token]', token
    assert_select 'input[name=?][value=?]', 'attachments[p0][filename]', 'myupload.txt'
    assert_select 'input[name=?][value=?]', 'attachments[p0][description]', 'My uploaded file'

    assert_difference 'Issue.count' do
      post '/projects/ecookbook/issues', {
          :issue => {:tracker_id => 1, :subject => 'Issue with upload'},
          :attachments => {'p0' => {:filename => 'myupload.txt', :description => 'My uploaded file', :token => token}}
        }
      assert_response 302
    end

    issue = Issue.order('id DESC').first
    assert_equal 'Issue with upload', issue.subject
    assert_equal 1, issue.attachments.count

    attachment = issue.attachments.first
    assert_equal 'myupload.txt', attachment.filename
    assert_equal 'My uploaded file', attachment.description
    assert_equal 'File content'.length, attachment.filesize
  end

  def test_upload_as_js_and_destroy
    log_user('jsmith', 'jsmith')

    token = ajax_upload('myupload.txt', 'File content')

    attachment = Attachment.order('id DESC').first
    attachment_path = "/attachments/#{attachment.id}.js?attachment_id=1"
    assert_include "href: '#{attachment_path}'", response.body, "Path to attachment: #{attachment_path} not found in response:\n#{response.body}"

    assert_difference 'Attachment.count', -1 do
      delete attachment_path
      assert_response :success
    end

    assert_include "$('#attachments_1').remove();", response.body
  end

  private

  def ajax_upload(filename, content, attachment_id=1)
    assert_difference 'Attachment.count' do
      post "/uploads.js?attachment_id=#{attachment_id}&filename=#{filename}", content, {"CONTENT_TYPE" => 'application/octet-stream'}
      assert_response :success
      assert_equal 'text/javascript', response.content_type
    end

    token = response.body.match(/\.val\('(\d+\.[0-9a-f]+)'\)/)[1]
    assert_not_nil token, "No upload token found in response:\n#{response.body}"
    token
  end
end
