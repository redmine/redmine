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

require_relative '../../../../../test_helper'
require 'redmine/scm/adapters/abstract_adapter'

class ScmDataTest < ActiveSupport::TestCase
  include Redmine::Scm::Adapters

  def test_binary_with_binary_data
    data = +"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x10"
    data.force_encoding('ASCII-8BIT')
    assert ScmData.binary?(data)
  end

  def test_binary_with_text_data
    data = "Flexible\nProject\tManagement\nSoftware\r\n"
    assert_not ScmData.binary?(data)
  end

  def test_binary_with_utf8_text_should_not_be_binary
    # full-width Latin letters ("\uFF32\uFF45\uFF44\uFF4D\uFF49\uFF4E\uFF45")
    data = "Ｒｅｄｍｉｎｅ"
    assert_not ScmData.binary?(data)
  end

  def test_binary_with_ascii_text_containing_0x00_should_be_binary
    data = +"null\0"
    assert ScmData.binary?(data)
  end
end
