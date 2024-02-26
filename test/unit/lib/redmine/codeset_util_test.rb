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

class Redmine::CodesetUtilTest < ActiveSupport::TestCase
  def test_to_utf8_by_setting_from_latin1
    with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
      s1 = 'Texte encodé'
      s2 = "Texte encod\xe9".b
      s3 = s2.dup.force_encoding("UTF-8")
      assert_equal s1, Redmine::CodesetUtil.to_utf8_by_setting(s2)
      assert_equal s1, Redmine::CodesetUtil.to_utf8_by_setting(s3)
    end
  end

  def test_to_utf8_by_setting_from_euc_jp
    with_settings :repositories_encodings => 'UTF-8,EUC-JP' do
      s1 = 'レッドマイン'
      s2 = "\xa5\xec\xa5\xc3\xa5\xc9\xa5\xde\xa5\xa4\xa5\xf3".b
      s3 = s2.dup.force_encoding("UTF-8")
      assert_equal s1, Redmine::CodesetUtil.to_utf8_by_setting(s2)
      assert_equal s1, Redmine::CodesetUtil.to_utf8_by_setting(s3)
    end
  end

  def test_to_utf8_by_setting_should_be_converted_all_latin1
    with_settings :repositories_encodings => 'ISO-8859-1' do
      s1 = "Â\u0080"
      s2 = "\xC2\x80".b
      s3 = s2.dup.force_encoding("UTF-8")
      assert_equal s1, Redmine::CodesetUtil.to_utf8_by_setting(s2)
      assert_equal s1, Redmine::CodesetUtil.to_utf8_by_setting(s3)
    end
  end

  def test_to_utf8_by_setting_blank_string
    assert_equal "",  Redmine::CodesetUtil.to_utf8_by_setting("")
    assert_nil Redmine::CodesetUtil.to_utf8_by_setting(nil)
  end

  def test_to_utf8_by_setting_returns_ascii_as_utf8
    s1 = 'ASCII'
    s2 = s1.dup.force_encoding("ISO-8859-1")
    str1 = Redmine::CodesetUtil.to_utf8_by_setting(s1)
    str2 = Redmine::CodesetUtil.to_utf8_by_setting(s2)
    assert_equal s1, str1
    assert_equal s1, str2
    assert_equal "UTF-8", str1.encoding.to_s
    assert_equal "UTF-8", str2.encoding.to_s
  end

  def test_to_utf8_by_setting_invalid_utf8_sequences_should_be_stripped
    with_settings :repositories_encodings => '' do
      s1 = "Texte encod\xe9 en ISO-8859-1.".b
      str = Redmine::CodesetUtil.to_utf8_by_setting(s1)
      assert str.valid_encoding?
      assert_equal "UTF-8", str.encoding.to_s
      assert_equal "Texte encod? en ISO-8859-1.", str
    end
  end

  def test_to_utf8_by_setting_invalid_utf8_sequences_should_be_stripped_ja_jis
    with_settings :repositories_encodings => 'ISO-2022-JP' do
      s1 = "test\xb5\xfetest\xb5\xfe".b
      str = Redmine::CodesetUtil.to_utf8_by_setting(s1)
      assert str.valid_encoding?
      assert_equal "UTF-8", str.encoding.to_s
      assert_equal "test??test??", str
    end
  end

  test "#replace_invalid_utf8 should replace invalid utf8" do
    s1 = "こんにち\xE3\x81\xFF"
    s2 = Redmine::CodesetUtil.replace_invalid_utf8(s1)
    assert s2.valid_encoding?
    assert_equal "UTF-8", s2.encoding.to_s
    assert_equal 'こんにち??', s2
  end

  test "#to_utf8 should replace invalid non utf8" do
    s1 = (+"\xa4\xb3\xa4\xf3\xa4\xcb\xa4\xc1\xa4").force_encoding("EUC-JP")
    s2 = Redmine::CodesetUtil.to_utf8(s1, "EUC-JP")
    assert s2.valid_encoding?
    assert_equal "UTF-8", s2.encoding.to_s
    assert_equal 'こんにち?', s2
  end

  def test_guess_encoding_should_return_guessed_encoding
    str = '日本語'.encode('Windows-31J').b
    with_settings :repositories_encodings => 'UTF-8,Windows-31J' do
      assert_equal 'Windows-31J', Redmine::CodesetUtil.guess_encoding(str)
    end
    with_settings :repositories_encodings => 'UTF-8,csWindows31J' do
      assert_equal 'csWindows31J', Redmine::CodesetUtil.guess_encoding(str)
    end
  end

  def guess_encoding_should_return_nil_if_cannot_guess_encoding
    str = '日本語'.encode('Windows-31J').b
    with_settings :repositories_encodings => 'UTF-8,EUC-JP' do
      assert_nil Redmine::CodesetUtil.guess_encoding(str)
    end
  end
end
