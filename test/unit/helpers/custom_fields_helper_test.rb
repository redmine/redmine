# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

require File.expand_path('../../../test_helper', __FILE__)

class CustomFieldsHelperTest < ActionView::TestCase
  include ApplicationHelper
  include CustomFieldsHelper
  include Redmine::I18n
  include ERB::Util

  def test_format_boolean_value
    I18n.locale = 'en'
    assert_equal 'Yes', format_value('1', CustomField.new(:field_format => 'bool'))
    assert_equal 'No', format_value('0', CustomField.new(:field_format => 'bool'))
  end

  def test_label_tag_should_include_description_as_span_title_if_present
    field = CustomField.new(:field_format => 'string', :description => 'This is the description')
    tag = custom_field_label_tag('foo', CustomValue.new(:custom_field => field))
    assert_select_in tag, 'label span[title=?]', 'This is the description'
  end

  def test_label_tag_should_not_include_title_if_description_is_blank
    field = CustomField.new(:field_format => 'string')
    tag = custom_field_label_tag('foo', CustomValue.new(:custom_field => field))
    assert_select_in tag, 'label span[title]', 0
  end

  def test_unknow_field_format_should_be_edited_as_string
    field = CustomField.new(:field_format => 'foo')
    value = CustomValue.new(:value => 'bar', :custom_field => field)
    field.id = 52

    assert_select_in custom_field_tag('object', value),
      'input[type=text][value=bar][name=?]', 'object[custom_field_values][52]'
  end

  def test_unknow_field_format_should_be_bulk_edited_as_string
    field = CustomField.new(:field_format => 'foo')
    field.id = 52

    assert_select_in custom_field_tag_for_bulk_edit('object', field),
      'input[type=text][value=""][name=?]', 'object[custom_field_values][52]'
  end
end
