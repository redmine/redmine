# encoding: utf-8
#
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

require File.expand_path('../../test_helper', __FILE__)

class AttachmentsVisibilityTest < Redmine::ControllerTest
  tests AttachmentsController
  fixtures :users, :email_addresses, :projects, :roles, :members, :member_roles,
           :enabled_modules, :projects_trackers, :issue_statuses, :enumerations,
           :issues, :trackers, :versions,
           :custom_fields, :custom_fields_trackers, :custom_fields_projects

  def setup
    User.current = nil
    set_tmp_attachments_directory

    @field = IssueCustomField.generate!(:field_format => 'attachment', :visible => true)
    @attachment = new_record(Attachment) do
      issue = Issue.generate
      issue.custom_field_values = {@field.id => {:file => mock_file}}
      issue.save!
    end
  end

  def test_attachment_should_be_visible
    @request.session[:user_id] = 2 # manager
    get :show, :params => {:id => @attachment.id}
    assert_response :success

    @field.update!(:visible => false, :role_ids => [1])
    get :show, :params => {:id => @attachment.id}
    assert_response :success
  end

  def test_attachment_should_be_visible_with_permission
    @request.session[:user_id] = 3 # developer
    get :show, :params => {:id => @attachment.id}
    assert_response :success

    @field.update!(:visible => false, :role_ids => [1])
    get :show, :params => {:id => @attachment.id}
    assert_response 403
  end
end
