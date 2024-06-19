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

class Redmine::Search::Tokenize < ActiveSupport::TestCase
  def test_tokenize
    value = "hello \"bye bye\""
    assert_equal ["hello", "bye bye"], Redmine::Search::Tokenizer.new(value).tokens
  end

  def test_tokenize_should_consider_ideographic_space_as_separator
    # U+3000 is an ideographic space ("　")
    value = "全角\u3000スペース"
    assert_equal %w[全角 スペース], Redmine::Search::Tokenizer.new(value).tokens
  end

  def test_tokenize_should_support_multiple_phrases
    value = '"phrase one" "phrase two"'
    assert_equal ["phrase one", "phrase two"], Redmine::Search::Tokenizer.new(value).tokens
  end
end
