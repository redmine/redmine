# encoding: utf-8
#
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

require File.expand_path('../../test_helper', __FILE__)

class AttachmentTest < ActiveSupport::TestCase
  fixtures :users, :projects, :roles, :members, :member_roles,
           :enabled_modules, :issues, :trackers, :attachments
  
  class MockFile
    attr_reader :original_filename, :content_type, :content, :size
    
    def initialize(attributes)
      @original_filename = attributes[:original_filename]
      @content_type = attributes[:content_type]
      @content = attributes[:content] || "Content"
      @size = content.size
    end
  end

  def setup
    set_tmp_attachments_directory
  end

  def test_create
    a = Attachment.new(:container => Issue.find(1),
                       :file => uploaded_test_file("testfile.txt", "text/plain"),
                       :author => User.find(1))
    assert a.save
    assert_equal 'testfile.txt', a.filename
    assert_equal 59, a.filesize
    assert_equal 'text/plain', a.content_type
    assert_equal 0, a.downloads
    assert_equal '1478adae0d4eb06d35897518540e25d6', a.digest
    assert File.exist?(a.diskfile)
    assert_equal 59, File.size(a.diskfile)
  end

  def test_destroy
    a = Attachment.new(:container => Issue.find(1),
                       :file => uploaded_test_file("testfile.txt", "text/plain"),
                       :author => User.find(1))
    assert a.save
    assert_equal 'testfile.txt', a.filename
    assert_equal 59, a.filesize
    assert_equal 'text/plain', a.content_type
    assert_equal 0, a.downloads
    assert_equal '1478adae0d4eb06d35897518540e25d6', a.digest
    diskfile = a.diskfile
    assert File.exist?(diskfile)
    assert_equal 59, File.size(a.diskfile)
    assert a.destroy
    assert !File.exist?(diskfile)
  end

  def test_create_should_auto_assign_content_type
    a = Attachment.new(:container => Issue.find(1),
                       :file => uploaded_test_file("testfile.txt", ""),
                       :author => User.find(1))
    assert a.save
    assert_equal 'text/plain', a.content_type
  end

  def test_identical_attachments_at_the_same_time_should_not_overwrite
    a1 = Attachment.create!(:container => Issue.find(1),
                            :file => uploaded_test_file("testfile.txt", ""),
                            :author => User.find(1))
    a2 = Attachment.create!(:container => Issue.find(1),
                            :file => uploaded_test_file("testfile.txt", ""),
                            :author => User.find(1))
    assert a1.disk_filename != a2.disk_filename
  end
  
  def test_filename_should_be_basenamed
    a = Attachment.new(:file => MockFile.new(:original_filename => "path/to/the/file"))
    assert_equal 'file', a.filename
  end
  
  def test_filename_should_be_sanitized
    a = Attachment.new(:file => MockFile.new(:original_filename => "valid:[] invalid:?%*|\"'<>chars"))
    assert_equal 'valid_[] invalid_chars', a.filename
  end

  def test_diskfilename
    assert Attachment.disk_filename("test_file.txt") =~ /^\d{12}_test_file.txt$/
    assert_equal 'test_file.txt', Attachment.disk_filename("test_file.txt")[13..-1]
    assert_equal '770c509475505f37c2b8fb6030434d6b.txt', Attachment.disk_filename("test_accentué.txt")[13..-1]
    assert_equal 'f8139524ebb8f32e51976982cd20a85d', Attachment.disk_filename("test_accentué")[13..-1]
    assert_equal 'cbb5b0f30978ba03731d61f9f6d10011', Attachment.disk_filename("test_accentué.ça")[13..-1]
  end

  context "Attachmnet.attach_files" do
    should "attach the file" do
      issue = Issue.first
      assert_difference 'Attachment.count' do
        Attachment.attach_files(issue,
          '1' => {
            'file' => uploaded_test_file('testfile.txt', 'text/plain'),
            'description' => 'test'
          })
      end

      attachment = Attachment.first(:order => 'id DESC')
      assert_equal issue, attachment.container
      assert_equal 'testfile.txt', attachment.filename
      assert_equal 59, attachment.filesize
      assert_equal 'test', attachment.description
      assert_equal 'text/plain', attachment.content_type
      assert File.exists?(attachment.diskfile)
      assert_equal 59, File.size(attachment.diskfile)
    end

    should "add unsaved files to the object as unsaved attachments" do
      # Max size of 0 to force Attachment creation failures
      with_settings(:attachment_max_size => 0) do
        @project = Project.generate!
        response = Attachment.attach_files(@project, {
                                             '1' => {'file' => mock_file, 'description' => 'test'},
                                             '2' => {'file' => mock_file, 'description' => 'test'}
                                           })

        assert response[:unsaved].present?
        assert_equal 2, response[:unsaved].length
        assert response[:unsaved].first.new_record?
        assert response[:unsaved].second.new_record?
        assert_equal response[:unsaved], @project.unsaved_attachments
      end
    end
  end

  def test_latest_attach
    Attachment.storage_path = "#{Rails.root}/test/fixtures/files"
    a1 = Attachment.find(16)
    assert_equal "testfile.png", a1.filename
    assert a1.readable?
    assert (! a1.visible?(User.anonymous))
    assert a1.visible?(User.find(2))
    a2 = Attachment.find(17)
    assert_equal "testfile.PNG", a2.filename
    assert a2.readable?
    assert (! a2.visible?(User.anonymous))
    assert a2.visible?(User.find(2))
    assert a1.created_on < a2.created_on

    la1 = Attachment.latest_attach([a1, a2], "testfile.png")
    assert_equal 17, la1.id
    la2 = Attachment.latest_attach([a1, a2], "Testfile.PNG")
    assert_equal 17, la2.id

    set_tmp_attachments_directory
  end
end
