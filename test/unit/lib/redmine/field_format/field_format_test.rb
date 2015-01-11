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

class Redmine::FieldFormatTest < ActionView::TestCase
  include ApplicationHelper

  def test_string_field_with_text_formatting_disabled_should_not_format_text
    field = IssueCustomField.new(:field_format => 'string')
    custom_value = CustomValue.new(:custom_field => field, :customized => Issue.new, :value => "*foo*")

    assert_equal "*foo*", field.format.formatted_custom_value(self, custom_value, false)
    assert_equal "*foo*", field.format.formatted_custom_value(self, custom_value, true)
  end

  def test_string_field_with_text_formatting_enabled_should_format_text
    field = IssueCustomField.new(:field_format => 'string', :text_formatting => 'full')
    custom_value = CustomValue.new(:custom_field => field, :customized => Issue.new, :value => "*foo*")

    assert_equal "*foo*", field.format.formatted_custom_value(self, custom_value, false)
    assert_include "<strong>foo</strong>", field.format.formatted_custom_value(self, custom_value, true)
  end

  def test_text_field_with_text_formatting_disabled_should_not_format_text
    field = IssueCustomField.new(:field_format => 'text')
    custom_value = CustomValue.new(:custom_field => field, :customized => Issue.new, :value => "*foo*\nbar")

    assert_equal "*foo*\nbar", field.format.formatted_custom_value(self, custom_value, false)
    assert_include "*foo*\n<br />bar", field.format.formatted_custom_value(self, custom_value, true)
  end

  def test_text_field_with_text_formatting_enabled_should_format_text
    field = IssueCustomField.new(:field_format => 'text', :text_formatting => 'full')
    custom_value = CustomValue.new(:custom_field => field, :customized => Issue.new, :value => "*foo*\nbar")

    assert_equal "*foo*\nbar", field.format.formatted_custom_value(self, custom_value, false)
    assert_include "<strong>foo</strong>", field.format.formatted_custom_value(self, custom_value, true)
  end

  def test_text_field_with_url_pattern_should_format_as_link
    field = IssueCustomField.new(:field_format => 'string', :url_pattern => 'http://foo/%value%')
    custom_value = CustomValue.new(:custom_field => field, :customized => Issue.new, :value => "bar")

    assert_equal "bar", field.format.formatted_custom_value(self, custom_value, false)
    assert_equal '<a href="http://foo/bar">bar</a>', field.format.formatted_custom_value(self, custom_value, true)
  end
end
