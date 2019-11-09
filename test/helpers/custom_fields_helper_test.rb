# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

require File.expand_path('../../test_helper', __FILE__)

class CustomFieldsHelperTest < Redmine::HelperTest
  include ApplicationHelper
  include CustomFieldsHelper
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

  def test_label_tag_should_include_for_attribute_for_select_tag
    field = CustomField.new(:name => 'Foo', :field_format => 'list')
    s = custom_field_tag_with_label('foo', CustomValue.new(:custom_field => field))
    assert_select_in s, 'label[for]'
  end

  def test_label_tag_should_not_include_for_attribute_for_checkboxes
    field = CustomField.new(:name => 'Foo', :field_format => 'list', :edit_tag_style => 'check_box')
    s = custom_field_tag_with_label('foo', CustomValue.new(:custom_field => field))
    assert_select_in s, 'label:not([for])'
  end

  def test_label_tag_should_include_for_attribute_for_bool_as_select_tag
    field = CustomField.new(:name => 'Foo', :field_format => 'bool')
    s = custom_field_tag_with_label('foo', CustomValue.new(:custom_field => field))
    assert_select_in s, 'label[for]'
  end

  def test_label_tag_should_include_for_attribute_for_bool_as_checkbox
    field = CustomField.new(:name => 'Foo', :field_format => 'bool', :edit_tag_style => 'check_box')
    s = custom_field_tag_with_label('foo', CustomValue.new(:custom_field => field))
    assert_select_in s, 'label[for]'
  end

  def test_label_tag_should_not_include_for_attribute_for_bool_as_radio
    field = CustomField.new(:name => 'Foo', :field_format => 'bool', :edit_tag_style => 'radio')
    s = custom_field_tag_with_label('foo', CustomValue.new(:custom_field => field))
    assert_select_in s, 'label:not([for])'
  end

  def test_unknow_field_format_should_be_edited_as_string
    field = CustomField.new(:field_format => 'foo')
    value = CustomValue.new(:value => 'bar', :custom_field => field)
    field.id = 52
    assert_select_in(
      custom_field_tag('object', value),
      'input[type=text][value=bar][name=?]', 'object[custom_field_values][52]')
  end

  def test_unknow_field_format_should_be_bulk_edited_as_string
    field = CustomField.new(:field_format => 'foo')
    field.id = 52
    assert_select_in(
      custom_field_tag_for_bulk_edit('object', field),
      'input[type=text][value=""][name=?]', 'object[custom_field_values][52]')
  end

  def test_custom_field_tag_class_should_contain_wiki_edit_for_custom_fields_with_full_text_formatting
    field = IssueCustomField.create!(:name => 'Long text', :field_format => 'text', :text_formatting => 'full')
    value = CustomValue.new(:value => 'bar', :custom_field => field)

    assert_select_in custom_field_tag('object', value), 'textarea[class=?]', 'text_cf wiki-edit'
  end

  def test_select_type_radio_buttons
    result = select_type_radio_buttons('UserCustomField')
    assert_select_in result, 'input[type="radio"]', :count => 10
    assert_select_in result, 'input#type_UserCustomField[checked=?]', 'checked'

    result = select_type_radio_buttons(nil)
    assert_select_in result, 'input[type="radio"]', :count => 10
    assert_select_in result, 'input#type_IssueCustomField[checked=?]', 'checked'
  end
end
