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

require File.expand_path('../../../../../test_helper', __FILE__)

class PdfTest < ActiveSupport::TestCase
  include Redmine::I18n

  def test_fix_text_encoding_backslash_ascii
    set_language_if_valid 'ja'
    pdf = Redmine::Export::PDF::IFPDF.new('ja')
    assert pdf
    assert_equal '\\\\abcd', pdf.fix_text_encoding('\\abcd')
    assert_equal 'abcd\\\\', pdf.fix_text_encoding('abcd\\')
    assert_equal 'ab\\\\cd', pdf.fix_text_encoding('ab\\cd')
    assert_equal '\\\\abcd\\\\', pdf.fix_text_encoding('\\abcd\\')
    assert_equal '\\\\abcd\\\\abcd\\\\',
                 pdf.fix_text_encoding('\\abcd\\abcd\\')
  end

  def test_fix_text_encoding_double_backslash_ascii
    set_language_if_valid 'ja'
    pdf = Redmine::Export::PDF::IFPDF.new('ja')
    assert pdf
    assert_equal '\\\\\\\\abcd', pdf.fix_text_encoding('\\\\abcd')
    assert_equal 'abcd\\\\\\\\', pdf.fix_text_encoding('abcd\\\\')
    assert_equal 'ab\\\\\\\\cd', pdf.fix_text_encoding('ab\\\\cd')
    assert_equal 'ab\\\\\\\\cd\\\\de', pdf.fix_text_encoding('ab\\\\cd\\de')
    assert_equal '\\\\\\\\abcd\\\\\\\\', pdf.fix_text_encoding('\\\\abcd\\\\')
    assert_equal '\\\\\\\\abcd\\\\\\\\abcd\\\\\\\\',
                 pdf.fix_text_encoding('\\\\abcd\\\\abcd\\\\')
  end
end
