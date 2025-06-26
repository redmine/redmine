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

require File.expand_path('../../../../../test_helper', __FILE__)

class PdfTest < ActiveSupport::TestCase
  fixtures :users, :projects, :roles, :members, :member_roles,
           :enabled_modules, :issues, :trackers, :attachments

  def test_fix_text_encoding_nil
    assert_equal '', Redmine::Export::PDF::RDMPdfEncoding::rdm_from_utf8(nil, "UTF-8")
    assert_equal '', Redmine::Export::PDF::RDMPdfEncoding::rdm_from_utf8(nil, "ISO-8859-1")
  end

  def test_rdm_pdf_iconv_cannot_convert_ja_cp932
    utf8_txt_1  = '狀態'
    utf8_txt_2  = '狀態狀'
    utf8_txt_3  = '狀狀態狀'
    ["CP932", "SJIS"].each do |encoding|
      txt_1 = Redmine::Export::PDF::RDMPdfEncoding::rdm_from_utf8(utf8_txt_1, encoding)
      txt_2 = Redmine::Export::PDF::RDMPdfEncoding::rdm_from_utf8(utf8_txt_2, encoding)
      txt_3 = Redmine::Export::PDF::RDMPdfEncoding::rdm_from_utf8(utf8_txt_3, encoding)
      assert_equal "?\x91\xd4".b, txt_1
      assert_equal "?\x91\xd4?".b, txt_2
      assert_equal "??\x91\xd4?".b, txt_3
      assert_equal "ASCII-8BIT", txt_1.encoding.to_s
      assert_equal "ASCII-8BIT", txt_2.encoding.to_s
      assert_equal "ASCII-8BIT", txt_3.encoding.to_s
    end
  end

  def test_rdm_pdf_iconv_invalid_utf8_should_be_replaced_en
    str1 = "Texte encod\xE9 en ISO-8859-1"
    str2 = "\xe9a\xe9b\xe9c\xe9d\xe9e test".b
    txt_1 = Redmine::Export::PDF::RDMPdfEncoding::rdm_from_utf8(str1, 'UTF-8')
    txt_2 = Redmine::Export::PDF::RDMPdfEncoding::rdm_from_utf8(str2, 'UTF-8')
    assert_equal "ASCII-8BIT", txt_1.encoding.to_s
    assert_equal "ASCII-8BIT", txt_2.encoding.to_s
    assert_equal "Texte encod? en ISO-8859-1", txt_1
    assert_equal "?a?b?c?d?e test", txt_2
  end

  def test_rdm_pdf_iconv_invalid_utf8_should_be_replaced_ja
    str1 = "Texte encod\xE9 en ISO-8859-1"
    str2 = "\xe9a\xe9b\xe9c\xe9d\xe9e test".b
    encoding = ( RUBY_PLATFORM == 'java' ? "SJIS" : "CP932" )
    txt_1 = Redmine::Export::PDF::RDMPdfEncoding::rdm_from_utf8(str1, encoding)
    txt_2 = Redmine::Export::PDF::RDMPdfEncoding::rdm_from_utf8(str2, encoding)
    assert_equal "ASCII-8BIT", txt_1.encoding.to_s
    assert_equal "ASCII-8BIT", txt_2.encoding.to_s
    assert_equal "Texte encod? en ISO-8859-1", txt_1
    assert_equal "?a?b?c?d?e test", txt_2
  end

  def test_attach
    set_fixtures_attachments_directory
    ["CP932", "SJIS"].each do |encoding|
      str2 = "\x83e\x83X\x83g".b

      a1 = Attachment.find(17)
      a2 = Attachment.find(19)
      User.current = User.find(1)
      assert a1.readable?
      assert a1.visible?
      assert a2.readable?
      assert a2.visible?

      aa1 = Redmine::Export::PDF::RDMPdfEncoding::attach(Attachment.all, "Testfile.PNG", "UTF-8")
      assert_not_nil aa1
      assert_equal 17, aa1.id

      aa2 = Redmine::Export::PDF::RDMPdfEncoding::attach(Attachment.all, "test#{str2}.png", encoding)
      assert_not_nil aa2
      assert_equal 19, aa2.id

      User.current = nil
      assert a1.readable?
      assert (! a1.visible?)
      assert a2.readable?
      assert (! a2.visible?)
      aa1 = Redmine::Export::PDF::RDMPdfEncoding::attach(Attachment.all, "Testfile.PNG", "UTF-8")
      assert_nil aa1
      aa2 = Redmine::Export::PDF::RDMPdfEncoding::attach(Attachment.all, "test#{str2}.png", encoding)
      assert_nil aa2
    end
  ensure
    set_tmp_attachments_directory
  end
end
