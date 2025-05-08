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

require_relative '../../../../test_helper'
require 'redmine/field_format'

class Redmine::BoolFieldFormatTest < ActionView::TestCase
  include Redmine::I18n

  def setup
    User.current = nil
    set_language_if_valid 'en'
  end

  def test_check_box_style_should_render_edit_tag_as_check_box
    field = IssueCustomField.new(:field_format => 'bool', :is_required => false, :edit_tag_style => 'check_box')
    value = CustomFieldValue.new(:custom_field => field, :customized => Issue.new)

    tag = field.format.edit_tag(self, 'abc', 'xyz', value)
    assert_select_in tag, 'input[name=xyz]', 2
    assert_select_in tag, 'input[id=abc]', 1
    assert_select_in tag, 'input[type=hidden][value="0"]'
    assert_select_in tag, 'input[type=checkbox][value="1"]'
  end

  def test_check_box_should_be_checked_when_value_is_set
    field = IssueCustomField.new(:field_format => 'bool', :is_required => false, :edit_tag_style => 'check_box')
    value = CustomFieldValue.new(:custom_field => field, :customized => Issue.new, :value => '1')

    tag = field.format.edit_tag(self, 'abc', 'xyz', value)
    assert_select_in tag, 'input[type=checkbox][value="1"][checked=checked]'
  end

  def test_radio_style_should_render_edit_tag_as_radio_buttons
    field = IssueCustomField.new(:field_format => 'bool', :is_required => false, :edit_tag_style => 'radio')
    value = CustomFieldValue.new(:custom_field => field, :customized => Issue.new)

    tag = field.format.edit_tag(self, 'abc', 'xyz', value)
    assert_select_in tag, 'input[type=radio][name=xyz]', 3
  end

  def test_default_style_should_render_edit_tag_as_select
    field = IssueCustomField.new(:field_format => 'bool', :is_required => false)
    value = CustomFieldValue.new(:custom_field => field, :customized => Issue.new)

    tag = field.format.edit_tag(self, 'abc', 'xyz', value)
    assert_select_in tag, 'select[name=xyz]', 1
  end
end
