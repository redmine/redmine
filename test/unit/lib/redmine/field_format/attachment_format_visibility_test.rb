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

require File.expand_path('../../../../../test_helper', __FILE__)
require 'redmine/field_format'

class AttachmentFormatVisibilityTest < ActionView::TestCase
  fixtures :projects, :enabled_modules, :projects_trackers,
           :roles, :members, :member_roles,
           :users, :email_addresses,
           :trackers, :issue_statuses, :enumerations, :issue_categories,
           :custom_fields, :custom_fields_trackers,
           :versions, :issues

  def setup
    User.current = nil
    set_tmp_attachments_directory
  end

  def test_attachment_should_be_visible_with_visible_custom_field
    field = IssueCustomField.generate!(:field_format => 'attachment', :visible => true)
    attachment = new_record(Attachment) do
      issue = Issue.generate
      issue.custom_field_values = {field.id => {:file => mock_file}}
      issue.save!
    end

    assert attachment.visible?(manager = User.find(2))
    assert attachment.visible?(developer = User.find(3))
    assert attachment.visible?(non_member = User.find(7))
    assert attachment.visible?(User.anonymous)
  end

  def test_attachment_should_be_visible_with_limited_visibility_custom_field
    field = IssueCustomField.generate!(:field_format => 'attachment', :visible => false, :role_ids => [1])
    attachment = new_record(Attachment) do
      issue = Issue.generate
      issue.custom_field_values = {field.id => {:file => mock_file}}
      issue.save!
    end

    assert attachment.visible?(manager = User.find(2))
    assert !attachment.visible?(developer = User.find(3))
    assert !attachment.visible?(non_member = User.find(7))
    assert !attachment.visible?(User.anonymous)
  end
end
