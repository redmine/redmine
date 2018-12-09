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

class Redmine::ApiTest::FilesTest < Redmine::ApiTest::Base
  fixtures :projects,
           :users,
           :members,
           :roles,
           :member_roles,
           :enabled_modules,
           :attachments,
           :versions

  test "GET /projects/:project_id/files.xml should return the list of uploaded files" do
    get '/projects/1/files.xml', :headers => credentials('jsmith')
    assert_response :success
    assert_select 'files>file>id', :text => '8'
  end

  test "POST /projects/:project_id/files.json should create a file" do
    set_tmp_attachments_directory
    post '/uploads.xml',
      :params => 'File content',
      :headers => {"CONTENT_TYPE" => 'application/octet-stream'}.merge(credentials('jsmith'))
    token = Attachment.last.token
    payload = <<-JSON
{ "file": {
    "token": "#{token}"
  }
}
    JSON
    post '/projects/1/files.json',
      :params => payload,
      :headers => {"CONTENT_TYPE" => 'application/json'}.merge(credentials('jsmith'))
    assert_response :success
    assert_equal 1, Attachment.last.container_id
    assert_equal "Project", Attachment.last.container_type
  end

  test "POST /projects/:project_id/files.xml should create a file" do
    set_tmp_attachments_directory
    post '/uploads.xml',
      :params => 'File content',
      :headers => {"CONTENT_TYPE" => 'application/octet-stream'}.merge(credentials('jsmith'))
    token = Attachment.last.token
    payload = <<-XML
<file>
  <token>#{token}</token>
</file>
    XML
    post '/projects/1/files.xml',
      :params => payload,
      :headers => {"CONTENT_TYPE" => 'application/xml'}.merge(credentials('jsmith'))
    assert_response :success
    assert_equal 1, Attachment.last.container_id
    assert_equal "Project", Attachment.last.container_type
  end

  test "POST /projects/:project_id/files.json should refuse requests without the :token parameter" do
    payload = <<-JSON
{ "file": {
    "filename": "project_file.zip",
  }
}
    JSON
    post '/projects/1/files.json',
      :params => payload,
      :headers => {"CONTENT_TYPE" => 'application/json'}.merge(credentials('jsmith'))
    assert_response :bad_request
  end

  test "POST /projects/:project_id/files.json should accept :filename, :description, :content_type as optional parameters" do
    set_tmp_attachments_directory
    post '/uploads.xml',
      :params => 'File content',
      :headers => {"CONTENT_TYPE" => 'application/octet-stream'}.merge(credentials('jsmith'))
    token = Attachment.last.token
    payload = <<-JSON
{ "file": {
    "filename": "New filename",
    "description": "New description",
    "content_type": "application/txt",
    "token": "#{token}"
  }
}
    JSON
    post '/projects/1/files.json',
      :params => payload,
      :headers => {"CONTENT_TYPE" => 'application/json'}.merge(credentials('jsmith'))
    assert_response :success
    assert_equal "New filename", Attachment.last.filename
    assert_equal "New description", Attachment.last.description
    assert_equal "application/txt", Attachment.last.content_type
  end

  test "POST /projects/:project_id/files.json should accept :version_id to attach the files to a version" do
    set_tmp_attachments_directory
    post '/uploads.xml',
      :params => 'File content',
      :headers => {"CONTENT_TYPE" => 'application/octet-stream'}.merge(credentials('jsmith'))
    token = Attachment.last.token
    payload = <<-JSON
{ "file": {
    "version_id": 3,
    "filename": "New filename",
    "description": "New description",
    "token": "#{token}"
  }
}
    JSON
    post '/projects/1/files.json',
      :params => payload,
      :headers => {"CONTENT_TYPE" => 'application/json'}.merge(credentials('jsmith'))
    assert_equal 3, Attachment.last.container_id
    assert_equal "Version", Attachment.last.container_type
  end
end
