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

require_relative '../test_helper'

class AttachmentTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  def setup
    User.current = nil
    set_tmp_attachments_directory
  end

  def test_rollback_after_create_should_remove_file_from_disk
    diskfile = nil

    Attachment.transaction do
      a = Attachment.new(:container => Issue.find(1),
                         :file => uploaded_test_file("testfile.txt", "text/plain"),
                         :author => User.find(1))
      a.save!
      diskfile = a.diskfile
      assert File.exist?(diskfile)
      raise ActiveRecord::Rollback
    end
    assert !File.exist?(diskfile)
  end

  def test_destroy_should_remove_file_from_disk_after_commit
    a = Attachment.new(:container => Issue.find(1),
                       :file => uploaded_test_file("testfile.txt", "text/plain"),
                       :author => User.find(1))
    a.save!
    diskfile = a.diskfile
    assert File.exist?(diskfile)

    Attachment.transaction do
      a.destroy
      assert File.exist?(diskfile)
    end
    assert !File.exist?(diskfile)
  end

  def test_rollback_after_destroy_should_not_remove_file_from_disk
    a = Attachment.new(:container => Issue.find(1),
                       :file => uploaded_test_file("testfile.txt", "text/plain"),
                       :author => User.find(1))
    a.save!
    diskfile = a.diskfile
    assert File.exist?(diskfile)

    Attachment.transaction do
      a.destroy
      raise ActiveRecord::Rollback
    end
    assert File.exist?(diskfile)
  end
end
