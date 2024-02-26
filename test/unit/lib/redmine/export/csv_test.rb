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

class CsvTest < ActiveSupport::TestCase
  include Redmine::I18n

  def test_should_include_bom_when_utf8_encoded
    with_locale 'sk' do
      string = Redmine::Export::CSV.generate {|csv| csv << %w(Foo Bar)}
      assert_equal 'UTF-8', string.encoding.name
      assert string.starts_with?("\xEF\xBB\xBF")
    end
  end

  def test_generate_should_return_strings_with_given_encoding
    with_locale 'en' do
      string = Redmine::Export::CSV.generate({encoding: 'ISO-8859-3'}) {|csv| csv << %w(Foo Bar)}
      assert_equal 'ISO-8859-3', string.encoding.name
      assert_not_equal l(:general_csv_encoding), string.encoding.name
    end
  end

  def test_generate_should_return_strings_with_general_csv_encoding_if_invalid_encoding_is_given
    with_locale 'en' do
      string = Redmine::Export::CSV.generate({encoding: 'invalid-encoding-name'}) {|csv| csv << %w(Foo Bar)}
      assert_equal l(:general_csv_encoding), string.encoding.name
    end
  end

  def test_generate_should_use_general_csv_separator_by_default
    with_locale 'fr' do
      string = Redmine::Export::CSV.generate {|csv| csv << %w(Foo Bar)}
      assert_equal ';', l(:general_csv_separator)
      assert 'Foo;Bar', string
    end
  end

  def test_generate_should_use_given_separator
    with_locale 'fr' do
      string = Redmine::Export::CSV.generate({field_separator: ','}) {|csv| csv << %w(Foo Bar)}
      assert_equal ';', l(:general_csv_separator)
      assert 'Foo,Bar', string
    end
  end
end
