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

require_relative '../../../test_helper'

class Redmine::ThumbnailTest < ActiveSupport::TestCase
  def test_valid_pdf_magic_returns_false_when_postscript_magic_comes_first
    # This PostScript file has a string '%PDF-' after '%!PS'.
    # Marcel currently misclassifies it as application/pdf, so we use
    # valid_pdf_magic? to avoid treating it as PDF.
    # TODO:
    # Consider removing `valid_pdf_magic?` once Marcel correctly
    # returns application/postscript.
    file = file_fixture('with_pdf_magic.ps')
    assert_equal 'application/pdf', file.open {|f| Marcel::MimeType.for(f)}
    assert_equal false, Redmine::Thumbnail.valid_pdf_magic?(file.to_s)
  end

  def test_valid_pdf_magic_returns_false_for_postscript
    file = file_fixture('hello.ps')
    assert_equal 'application/postscript', file.open {|f| Marcel::MimeType.for(f)}
    assert_equal false, Redmine::Thumbnail.valid_pdf_magic?(file.to_s)
  end

  def test_valid_pdf_magic_returns_true_for_pdf
    file = file_fixture('hello.pdf')
    assert_equal 'application/pdf', file.open {|f| Marcel::MimeType.for(f)}
    assert_equal true, Redmine::Thumbnail.valid_pdf_magic?(file.to_s)
  end

  def test_thumbnail_returns_nil_for_postscript
    skip unless Redmine::Thumbnail.convert_available? && Redmine::Thumbnail.gs_available?

    set_tmp_attachments_directory
    file = file_fixture('with_pdf_magic.ps')
    target = File.join(Attachment.storage_path, "#{SecureRandom.hex(8)}.thumb.png")
    assert_nil Redmine::Thumbnail.generate(file.to_s, target, 100)
    assert_not File.exist?(target)
  ensure
    FileUtils.rm_f(target) if target
  end

  def test_thumbnail_returns_thumbnail_filename_for_pdf
    skip unless Redmine::Thumbnail.convert_available? && Redmine::Thumbnail.gs_available?

    set_tmp_attachments_directory
    file = file_fixture('hello.pdf')
    target = File.join(Attachment.storage_path, "#{SecureRandom.hex(8)}.thumb.png")
    result = Redmine::Thumbnail.generate(file.to_s, target, 100)
    assert_equal target, result
    assert File.exist?(target)
  ensure
    FileUtils.rm_f(target) if target
  end
end
