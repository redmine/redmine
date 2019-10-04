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

require File.expand_path('../../test_helper', __FILE__)

class JournalsHelperTest < Redmine::HelperTest
  include JournalsHelper

  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :issue_categories,
           :projects_trackers,
           :users, :roles, :member_roles, :members,
           :enabled_modules,
           :custom_fields,
           :attachments,
           :versions

  def test_journal_thumbnail_attachments_should_return_thumbnailable_attachments
    set_tmp_attachments_directory
    issue = Issue.generate!

    journal = new_record(Journal) do
      issue.init_journal(User.find(1))
      issue.attachments << Attachment.new(:file => mock_file_with_options(:original_filename => 'image.png'), :author => User.find(1))
      issue.attachments << Attachment.new(:file => mock_file_with_options(:original_filename => 'foo'), :author => User.find(1))
      issue.save
    end
    assert_equal 2, journal.details.count

    thumbnails = journal_thumbnail_attachments(journal)
    assert_equal 1, thumbnails.count
    assert_kind_of Attachment, thumbnails.first
    assert_equal 'image.png', thumbnails.first.filename
  end
end
