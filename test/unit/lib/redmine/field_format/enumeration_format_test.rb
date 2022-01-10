# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

class Redmine::EnumerationFieldFormatTest < ActionView::TestCase
  include ApplicationHelper

  def setup
    User.current = nil
    set_language_if_valid 'en'
    @field = IssueCustomField.create!(:name => 'List', :field_format => 'enumeration', :is_required => false)
    @foo = CustomFieldEnumeration.new(:name => 'Foo')
    @bar = CustomFieldEnumeration.new(:name => 'Bar')
    @field.enumerations << @foo
    @field.enumerations << @bar
  end

  def test_edit_tag_should_contain_possible_values
    value = CustomFieldValue.new(:custom_field => @field, :customized => Issue.new)

    tag = @field.format.edit_tag(self, 'id', 'name', value)
    assert_select_in tag, 'select' do
      assert_select 'option', 3
      assert_select 'option[value=""]'
      assert_select 'option[value=?]', @foo.id.to_s, :text => 'Foo'
      assert_select 'option[value=?]', @bar.id.to_s, :text => 'Bar'
    end
  end

  def test_edit_tag_should_select_current_value
    value = CustomFieldValue.new(:custom_field => @field, :customized => Issue.new, :value => @bar.id.to_s)

    tag = @field.format.edit_tag(self, 'id', 'name', value)
    assert_select_in tag, 'select' do
      assert_select 'option[selected=selected]', 1
      assert_select 'option[value=?][selected=selected]', @bar.id.to_s, :text => 'Bar'
    end
  end

  def test_edit_tag_with_multiple_should_select_current_values
    @field.multiple = true
    @field.save!
    value = CustomFieldValue.new(:custom_field => @field, :customized => Issue.new, :value => [@foo.id.to_s, @bar.id.to_s])

    tag = @field.format.edit_tag(self, 'id', 'name', value)
    assert_select_in tag, 'select[multiple=multiple]' do
      assert_select 'option[selected=selected]', 2
      assert_select 'option[value=?][selected=selected]', @foo.id.to_s, :text => 'Foo'
      assert_select 'option[value=?][selected=selected]', @bar.id.to_s, :text => 'Bar'
    end
  end

  def test_edit_tag_with_check_box_style_should_contain_possible_values
    @field.edit_tag_style = 'check_box'
    @field.save!
    value = CustomFieldValue.new(:custom_field => @field, :customized => Issue.new)

    tag = @field.format.edit_tag(self, 'id', 'name', value)
    assert_select_in tag, 'span' do
      assert_select 'input[type=radio]', 3
      assert_select 'label', :text => '(none)' do
        assert_select 'input[value=""]'
      end
      assert_select 'label', :text => 'Foo' do
        assert_select 'input[value=?]', @foo.id.to_s
      end
      assert_select 'label', :text => 'Bar' do
        assert_select 'input[value=?]', @bar.id.to_s
      end
    end
  end

  def test_value_from_keyword_should_return_enumeration_id
    assert_equal @foo.id, @field.value_from_keyword('foo', nil)
    assert_nil @field.value_from_keyword('baz', nil)
  end

  def test_value_from_keyword_for_multiple_custom_field_should_return_enumeration_ids
    @field.multiple = true
    @field.save!
    assert_equal [@foo.id, @bar.id], @field.value_from_keyword('foo, bar', nil)
    assert_equal [@foo.id], @field.value_from_keyword('foo, baz', nil)
    assert_equal [], @field.value_from_keyword('baz', nil)
  end
end
