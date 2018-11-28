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
require 'redmine/field_format'

class Redmine::ListFieldFormatTest < ActionView::TestCase
  include ApplicationHelper
  include Redmine::I18n

  def setup
    set_language_if_valid 'en'
  end

  def test_possible_existing_value_should_be_valid
    field = GroupCustomField.create!(:name => 'List', :field_format => 'list', :possible_values => ['Foo', 'Bar'])
    group = Group.new(:name => 'Group')
    group.custom_field_values = {field.id => 'Baz'}
    assert group.save(:validate => false)

    group = Group.order('id DESC').first
    assert_equal ['Foo', 'Bar', 'Baz'], field.possible_custom_value_options(group.custom_value_for(field))
    assert group.valid?
  end

  def test_non_existing_value_should_be_invalid
    field = GroupCustomField.create!(:name => 'List', :field_format => 'list', :possible_values => ['Foo', 'Bar'])
    group = Group.new(:name => 'Group')
    group.custom_field_values = {field.id => 'Baz'}

    assert_not_include 'Baz', field.possible_custom_value_options(group.custom_value_for(field))
    assert_equal false, group.valid?
    assert_include "List #{::I18n.t('activerecord.errors.messages.inclusion')}", group.errors.full_messages.first
  end

  def test_edit_tag_should_have_id_and_name
    field = IssueCustomField.new(:field_format => 'list', :possible_values => ['Foo', 'Bar'], :is_required => false)
    value = CustomFieldValue.new(:custom_field => field, :customized => Issue.new)

    tag = field.format.edit_tag(self, 'abc', 'xyz', value)
    assert_select_in tag, 'select[id=abc][name=xyz]'
  end

  def test_edit_tag_should_contain_possible_values
    field = IssueCustomField.new(:field_format => 'list', :possible_values => ['Foo', 'Bar'], :is_required => false)
    value = CustomFieldValue.new(:custom_field => field, :customized => Issue.new)

    tag = field.format.edit_tag(self, 'id', 'name', value)
    assert_select_in tag, 'select' do
      assert_select 'option', 3
      assert_select 'option[value=""]'
      assert_select 'option[value=Foo]', :text => 'Foo'
      assert_select 'option[value=Bar]', :text => 'Bar'
    end
  end

  def test_edit_tag_should_select_current_value
    field = IssueCustomField.new(:field_format => 'list', :possible_values => ['Foo', 'Bar'], :is_required => false)
    value = CustomFieldValue.new(:custom_field => field, :customized => Issue.new, :value => 'Bar')

    tag = field.format.edit_tag(self, 'id', 'name', value)
    assert_select_in tag, 'select' do
      assert_select 'option[selected=selected]', 1
      assert_select 'option[value=Bar][selected=selected]', :text => 'Bar'
    end
  end

  def test_edit_tag_with_multiple_should_select_current_values
    field = IssueCustomField.new(:field_format => 'list', :possible_values => ['Foo', 'Bar', 'Baz'], :is_required => false,
      :multiple => true)
    value = CustomFieldValue.new(:custom_field => field, :customized => Issue.new, :value => ['Bar', 'Baz'])

    tag = field.format.edit_tag(self, 'id', 'name', value)
    assert_select_in tag, 'select[multiple=multiple]' do
      assert_select 'option[selected=selected]', 2
      assert_select 'option[value=Bar][selected=selected]', :text => 'Bar'
      assert_select 'option[value=Baz][selected=selected]', :text => 'Baz'
    end
  end

  def test_edit_tag_with_check_box_style_should_contain_possible_values
    field = IssueCustomField.new(:field_format => 'list', :possible_values => ['Foo', 'Bar'], :is_required => false,
      :edit_tag_style => 'check_box')
    value = CustomFieldValue.new(:custom_field => field, :customized => Issue.new)

    tag = field.format.edit_tag(self, 'id', 'name', value)
    assert_select_in tag, 'span' do
      assert_select 'input[type=radio]', 3
      assert_select 'label', :text => '(none)' do
        assert_select 'input[value=""]'
      end
      assert_select 'label', :text => 'Foo' do
        assert_select 'input[value=Foo]'
      end
      assert_select 'label', :text => 'Bar' do
        assert_select 'input[value=Bar]'
      end
    end
  end

  def test_edit_tag_with_check_box_style_should_select_current_value
    field = IssueCustomField.new(:field_format => 'list', :possible_values => ['Foo', 'Bar'], :is_required => false,
      :edit_tag_style => 'check_box')
    value = CustomFieldValue.new(:custom_field => field, :customized => Issue.new, :value => 'Bar')

    tag = field.format.edit_tag(self, 'id', 'name', value)
    assert_select_in tag, 'span' do
      assert_select 'input[type=radio][checked=checked]', 1
      assert_select 'label', :text => 'Bar' do
        assert_select 'input[value=Bar][checked=checked]'
      end
    end
  end

  def test_edit_tag_with_check_box_style_and_multiple_values_should_contain_hidden_field_to_clear_value
    field = IssueCustomField.new(:field_format => 'list', :possible_values => ['Foo', 'Bar'], :is_required => false,
      :edit_tag_style => 'check_box', :multiple => true)
    value = CustomFieldValue.new(:custom_field => field, :customized => Issue.new)

    tag = field.format.edit_tag(self, 'id', 'name', value)
    assert_select_in tag, 'span' do
      assert_select 'input[type=checkbox]', 2
      assert_select 'input[type=hidden]', 1
    end
  end

  def test_field_with_url_pattern_should_link_value
    field = IssueCustomField.new(:field_format => 'list', :url_pattern => 'http://localhost/%value%')
    formatted = field.format.formatted_value(self, field, 'foo', Issue.new, true)
    assert_equal '<a class="external" href="http://localhost/foo">foo</a>', formatted
    assert formatted.html_safe?
  end

  def test_field_with_url_pattern_and_multiple_values_should_link_values
    field = IssueCustomField.new(:field_format => 'list', :url_pattern => 'http://localhost/%value%')
    formatted = field.format.formatted_value(self, field, ['foo', 'bar'], Issue.new, true)
    assert_equal '<a class="external" href="http://localhost/bar">bar</a>, <a class="external" href="http://localhost/foo">foo</a>', formatted
    assert formatted.html_safe?
  end

  def test_field_with_url_pattern_should_not_link_blank_value
    field = IssueCustomField.new(:field_format => 'list', :url_pattern => 'http://localhost/%value%')
    formatted = field.format.formatted_value(self, field, '', Issue.new, true)
    assert_equal '', formatted
    assert formatted.html_safe?
  end

  def test_edit_tag_with_check_box_style_and_multiple_should_select_current_values
    field = IssueCustomField.new(:field_format => 'list', :possible_values => ['Foo', 'Bar', 'Baz'], :is_required => false,
      :multiple => true, :edit_tag_style => 'check_box')
    value = CustomFieldValue.new(:custom_field => field, :customized => Issue.new, :value => ['Bar', 'Baz'])

    tag = field.format.edit_tag(self, 'id', 'name', value)
    assert_select_in tag, 'span' do
      assert_select 'input[type=checkbox][checked=checked]', 2
      assert_select 'label', :text => 'Bar' do
        assert_select 'input[value=Bar][checked=checked]'
      end
      assert_select 'label', :text => 'Baz' do
        assert_select 'input[value=Baz][checked=checked]'
      end
    end
  end

  def test_value_from_keyword_should_return_value
    field = GroupCustomField.create!(:name => 'List', :field_format => 'list', :possible_values => ['Foo', 'Bar', 'Baz,qux'])

    assert_equal 'Foo', field.value_from_keyword('foo', nil)
    assert_equal 'Baz,qux', field.value_from_keyword('baz,qux', nil)
    assert_nil field.value_from_keyword('invalid', nil)
  end

  def test_value_from_keyword_for_multiple_custom_field_should_return_values
    field = GroupCustomField.create!(:name => 'List', :field_format => 'list', :possible_values => ['Foo', 'Bar', 'Baz,qux'], :multiple => true)

    assert_equal ['Foo','Bar'], field.value_from_keyword('foo,bar', nil)
    assert_equal ['Baz,qux'], field.value_from_keyword('baz,qux', nil)
    assert_equal ['Baz,qux', 'Foo'], field.value_from_keyword('baz,qux,foo', nil)
    assert_equal ['Foo'], field.value_from_keyword('foo,invalid', nil)
    assert_equal ['Foo'], field.value_from_keyword(',foo,', nil)
    assert_equal ['Foo'], field.value_from_keyword(',foo, ,,', nil)
    assert_equal [], field.value_from_keyword('invalid', nil)
  end
end
