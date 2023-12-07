# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2023  Jean-Philippe Lang
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

class Redmine::WikiFormatting::CommonMark::HelperTest < Redmine::HelperTest
  if Object.const_defined?(:CommonMarker)

    def test_help_path_should_reflect_language
      assert_equal '/help/de/wiki_syntax_common_mark.html', help_path('de')
    end

    def test_help_path_should_fallback_to_english
      assert_equal '/help/en/wiki_syntax_common_mark.html', help_path('xx')
    end
  end
end
