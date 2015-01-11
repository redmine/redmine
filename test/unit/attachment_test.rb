# encoding: utf-8
#
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

  def test_container_for_new_attachment_should_be_nil
    assert_nil Attachment.new.container
  end

  def test_filename_should_remove_eols
    assert_equal "line_feed", Attachment.new(:filename => "line\nfeed").filename
    assert_equal "line_feed", Attachment.new(:filename => "some\npath/line\nfeed").filename
    assert_equal "carriage_return", Attachment.new(:filename => "carriage\rreturn").filename
    assert_equal "carriage_return", Attachment.new(:filename => "some\rpath/carriage\rreturn").filename
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

    assert a.disk_directory
    assert_match %r{\A\d{4}/\d{2}\z}, a.disk_directory

    assert File.exist?(a.diskfile)
    assert_equal 59, File.size(a.diskfile)
  end

  def test_create_should_clear_content_type_if_too_long
    a = Attachment.new(:container => Issue.find(1),
                       :file => uploaded_test_file("testfile.txt", "text/plain"),
                       :author => User.find(1),
                       :content_type => 'a'*300)
    assert a.save
    a.reload
    assert_nil a.content_type
  end

  def test_copy_should_preserve_attributes
    a = Attachment.find(1)
    copy = a.copy

    assert_save copy
    copy = Attachment.order('id DESC').first
    %w(filename filesize content_type author_id created_on description digest disk_filename disk_directory diskfile).each do |attribute|
      assert_equal a.send(attribute), copy.send(attribute), "#{attribute} was different"
    end
  end

  def test_size_should_be_validated_for_new_file
    with_settings :attachment_max_size => 0 do
      a = Attachment.new(:container => Issue.find(1),
                         :file => uploaded_test_file("testfile.txt", "text/plain"),
                         :author => User.find(1))
      assert !a.save
    end
  end

  def test_size_should_not_be_validated_when_copying
    a = Attachment.create!(:container => Issue.find(1),
                           :file => uploaded_test_file("testfile.txt", "text/plain"),
                           :author => User.find(1))
    with_settings :attachment_max_size => 0 do
      copy = a.copy
      assert copy.save
    end
  end

  def test_description_length_should_be_validated
    a = Attachment.new(:description => 'a' * 300)
    assert !a.save
    assert_not_equal [], a.errors[:description]
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

  def test_destroy_should_not_delete_file_referenced_by_other_attachment
    a = Attachment.create!(:container => Issue.find(1),
                           :file => uploaded_test_file("testfile.txt", "text/plain"),
                           :author => User.find(1))
    diskfile = a.diskfile

    copy = a.copy
    copy.save!

    assert File.exists?(diskfile)
    a.destroy
    assert File.exists?(diskfile)
    copy.destroy
    assert !File.exists?(diskfile)
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

  def test_title
    a = Attachment.new(:filename => "test.png")
    assert_equal "test.png", a.title

    a = Attachment.new(:filename => "test.png", :description => "Cool image")
    assert_equal "test.png (Cool image)", a.title
  end

  def test_new_attachment_should_be_editable_by_authot
    user = User.find(1)
    a = Attachment.new(:author => user)
    assert_equal true, a.editable?(user)
  end

  def test_prune_should_destroy_old_unattached_attachments
    Attachment.create!(:file => uploaded_test_file("testfile.txt", ""), :author_id => 1, :created_on => 2.days.ago)
    Attachment.create!(:file => uploaded_test_file("testfile.txt", ""), :author_id => 1, :created_on => 2.days.ago)
    Attachment.create!(:file => uploaded_test_file("testfile.txt", ""), :author_id => 1)

    assert_difference 'Attachment.count', -2 do
      Attachment.prune
    end
  end

  def test_move_from_root_to_target_directory_should_move_root_files
    a = Attachment.find(20)
    assert a.disk_directory.blank?
    # Create a real file for this fixture
    File.open(a.diskfile, "w") do |f|
      f.write "test file at the root of files directory"
    end
    assert a.readable?
    Attachment.move_from_root_to_target_directory

    a.reload
    assert_equal '2012/05', a.disk_directory
    assert a.readable?
  end

  test "Attachmnet.attach_files should attach the file" do
    issue = Issue.first
    assert_difference 'Attachment.count' do
      Attachment.attach_files(issue,
        '1' => {
          'file' => uploaded_test_file('testfile.txt', 'text/plain'),
          'description' => 'test'
        })
    end
    attachment = Attachment.order('id DESC').first
    assert_equal issue, attachment.container
    assert_equal 'testfile.txt', attachment.filename
    assert_equal 59, attachment.filesize
    assert_equal 'test', attachment.description
    assert_equal 'text/plain', attachment.content_type
    assert File.exists?(attachment.diskfile)
    assert_equal 59, File.size(attachment.diskfile)
  end

  test "Attachmnet.attach_files should add unsaved files to the object as unsaved attachments" do
    # Max size of 0 to force Attachment creation failures
    with_settings(:attachment_max_size => 0) do
      @project = Project.find(1)
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

  test "Attachment.attach_files should preserve the content_type of attachments added by token" do
    @project = Project.find(1)
    attachment = Attachment.create!(:file => uploaded_test_file("testfile.txt", ""), :author_id => 1, :created_on => 2.days.ago)
    assert_equal 'text/plain', attachment.content_type
    Attachment.attach_files(@project, { '1' => {'token' => attachment.token } })
    attachment.reload
    assert_equal 'text/plain', attachment.content_type
  end

  def test_update_attachments
    attachments = Attachment.where(:id => [2, 3]).to_a

    assert Attachment.update_attachments(attachments, {
      '2' => {:filename => 'newname.txt', :description => 'New description'},
      3 => {:filename => 'othername.txt'}
    })

    attachment = Attachment.find(2)
    assert_equal 'newname.txt', attachment.filename
    assert_equal 'New description', attachment.description

    attachment = Attachment.find(3)
    assert_equal 'othername.txt', attachment.filename
  end

  def test_update_attachments_with_failure
    attachments = Attachment.where(:id => [2, 3]).to_a

    assert !Attachment.update_attachments(attachments, {
      '2' => {:filename => '', :description => 'New description'},
      3 => {:filename => 'othername.txt'}
    })

    attachment = Attachment.find(3)
    assert_equal 'logo.gif', attachment.filename
  end

  def test_update_attachments_should_sanitize_filename
    attachments = Attachment.where(:id => 2).to_a

    assert Attachment.update_attachments(attachments, {
      2 => {:filename => 'newname?.txt'},
    })

    attachment = Attachment.find(2)
    assert_equal 'newname_.txt', attachment.filename
  end

  def test_latest_attach
    set_fixtures_attachments_directory
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

  def test_thumbnailable_should_be_true_for_images
    assert_equal true, Attachment.new(:filename => 'test.jpg').thumbnailable?
  end

  def test_thumbnailable_should_be_true_for_non_images
    assert_equal false, Attachment.new(:filename => 'test.txt').thumbnailable?
  end

  if convert_installed?
    def test_thumbnail_should_generate_the_thumbnail
      set_fixtures_attachments_directory
      attachment = Attachment.find(16)
      Attachment.clear_thumbnails

      assert_difference "Dir.glob(File.join(Attachment.thumbnails_storage_path, '*.thumb')).size" do
        thumbnail = attachment.thumbnail
        assert_equal "16_8e0294de2441577c529f170b6fb8f638_100.thumb", File.basename(thumbnail)
        assert File.exists?(thumbnail)
      end
    end

    def test_thumbnail_should_return_nil_if_generation_fails
      Redmine::Thumbnail.expects(:generate).raises(SystemCallError, 'Something went wrong')
      set_fixtures_attachments_directory
      attachment = Attachment.find(16)
      assert_nil attachment.thumbnail
    end
  else
    puts '(ImageMagick convert not available)'
  end
end
