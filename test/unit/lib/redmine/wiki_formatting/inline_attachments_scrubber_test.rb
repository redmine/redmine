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

require_relative '../../../../test_helper'

class Redmine::WikiFormatting::InlineAttachmentsScrubberTest < Redmine::HelperTest
  def setup
    super
    set_tmp_attachments_directory
  end

  def filter(html, options = {})
    fragment = Redmine::WikiFormatting::HtmlParser.parse(html)
    options[:only_path] = true unless options.key?(:only_path)
    scrubber = Redmine::WikiFormatting::InlineAttachmentsScrubber.new(options.merge(view: view))
    fragment.scrub!(scrubber)
    fragment.to_s
  end

  def test_should_resolve_attached_images
    to_test = [
      "test.bmp",
      "test.gif",
      "test.jpg",
      "test.jpeg",
      "test.jpe",
      "test.png",
      "test.webp"
    ]

    to_test.each do |file|
      a = Attachment.generate!(:file => mock_file_with_options(:original_filename => file))
      html = %(<img src="#{file}" alt="">)
      assert_equal %(<img src="/attachments/download/#{a.id}/#{file}" alt="" loading="lazy">), filter(html, :attachments => [a])
    end
  end

  def test_should_resolve_attached_images_with_case_insensitive_filename
    attachment = Attachment.generate!(:file => mock_file_with_options(:original_filename => "logo.gif"), :description => "This is a logo")

    html = '<img src="logo.GIF" alt="">'
    expected = %(<img src="/attachments/download/#{attachment.id}/logo.gif" alt="This is a logo" title="This is a logo" loading="lazy">)
    assert_equal expected, filter(html, :attachments => [attachment])
  end

  def test_should_not_resolve_images_that_do_not_match_attachments
    html = '<img src="ogo.gif" alt="">'
    assert_equal html, filter(html, :attachments => [])
  end

  def test_should_handle_non_ascii_filenames
    to_test = {
      'CAFÉ.JPG' => 'CAF%C3%89.JPG',
      'crème.jpg' => 'cr%C3%A8me.jpg',
    }

    to_test.each do |filename, result|
      attachment = Attachment.generate!(:filename => filename)
      html = %(<img src="#{result}" alt="">)
      expected = %(<img src="/attachments/download/#{attachment.id}/#{result}" alt="" loading="lazy">)

      assert_equal expected, filter(html, :attachments => [attachment])
    end
  end

  def test_should_add_title_and_alt_if_alt_blank
    attachment = Attachment.generate!(:file => mock_file_with_options(:original_filename => "logo.gif"), :description => "This is a logo")

    html = '<img src="logo.gif">'
    expected = %(<img src="/attachments/download/#{attachment.id}/logo.gif" title="This is a logo" alt="This is a logo" loading="lazy">)
    assert_equal expected, filter(html, :attachments => [attachment])
  end

  def test_should_respect_alt_attribute_if_already_set
    attachment = Attachment.generate!(:file => mock_file_with_options(:original_filename => "logo.gif"), :description => "This is a logo")

    html = '<img src="logo.gif" alt="alt text">'
    # Should keep "alt text" and NOT set title/alt from description
    expected = %(<img src="/attachments/download/#{attachment.id}/logo.gif" alt="alt text" loading="lazy">)
    assert_equal expected, filter(html, :attachments => [attachment])
  end

  def test_should_resolve_attachments_on_issue
    issue = Issue.generate!
    attachment = Attachment.generate!(:file => mock_file_with_options(:original_filename => "attached_on_issue.png"), :container => issue)

    html = '<img src="attached_on_issue.png" alt="">'
    expected = %(<img src="/attachments/download/#{attachment.id}/attached_on_issue.png" alt="" loading="lazy">)
    assert_equal expected, filter(html, :object => issue)
  end

  def test_should_resolve_attachments_from_journal
    issue = Issue.generate!
    attachment1 = Attachment.generate!(:file => mock_file_with_options(:original_filename => "attached_on_issue.png"), :container => issue)
    journal = issue.init_journal(User.find(2), issue)
    attachment2 = Attachment.generate!(:file => mock_file_with_options(:original_filename => "attached_on_journal.png"), :container => issue)
    journal.journalize_attachment(attachment2, :added)

    html = '<img src="attached_on_issue.png" alt=""><img src="attached_on_journal.png" alt="">'
    expected = %(<img src="/attachments/download/#{attachment1.id}/attached_on_issue.png" alt="" loading="lazy">) +
               %(<img src="/attachments/download/#{attachment2.id}/attached_on_journal.png" alt="" loading="lazy">)
    assert_equal expected, filter(html, :object => journal)
  end

  def test_should_use_the_latest_attachment_when_multiple_attachments_have_the_same_name
    set_fixtures_attachments_directory
    a1 = Attachment.find(16) # testfile.png
    a2 = Attachment.find(17) # testfile.PNG
    assert_equal "testfile.png", a1.filename
    assert_equal "testfile.PNG", a2.filename
    assert a1.created_on < a2.created_on

    html = '<img src="testfile.png" alt="">'
    expected = %(<img src="/attachments/download/#{a2.id}/testfile.PNG" alt="" loading="lazy">)
    assert_equal expected, filter(html, :attachments => [a1, a2])
  ensure
    set_tmp_attachments_directory
  end
end
