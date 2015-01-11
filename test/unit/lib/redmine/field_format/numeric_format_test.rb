# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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
require 'redmine/field_format'

class Redmine::NumericFieldFormatTest < ActionView::TestCase
  include ApplicationHelper

  def test_integer_field_with_url_pattern_should_format_as_link
    field = IssueCustomField.new(:field_format => 'int', :url_pattern => 'http://foo/%value%')
    custom_value = CustomValue.new(:custom_field => field, :customized => Issue.new, :value => "3")

    assert_equal 3, field.format.formatted_custom_value(self, custom_value, false)
    assert_equal '<a href="http://foo/3">3</a>', field.format.formatted_custom_value(self, custom_value, true)
  end
end
