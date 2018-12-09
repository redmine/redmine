# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

class Redmine::SyntaxHighlighting::CodeRayTest < ActiveSupport::TestCase
  def test_retrieve_supported_languages_should_return_array_of_symbols
    assert_kind_of Array, Redmine::SyntaxHighlighting::CodeRay.send(:retrieve_supported_languages)
    assert_kind_of Symbol, Redmine::SyntaxHighlighting::CodeRay.send(:retrieve_supported_languages).first
  end

  def test_retrieve_supported_languages_should_return_array_of_symbols_holding_languages
    assert_includes Redmine::SyntaxHighlighting::CodeRay.send(:retrieve_supported_languages), :ruby
  end

  def test_retrieve_supported_languages_should_return_array_of_symbols_holding_languages_aliases
    assert_includes Redmine::SyntaxHighlighting::CodeRay.send(:retrieve_supported_languages), :javascript
  end

  def test_retrieve_supported_languages_should_return_array_of_symbols_not_holding_internal_languages
    refute_includes Redmine::SyntaxHighlighting::CodeRay.send(:retrieve_supported_languages), :default
  end
end
