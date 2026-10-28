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

require_relative '../test_helper'

class TimeEntryCustomFieldTest < ActiveSupport::TestCase
  include Redmine::I18n

  def setup
    User.current = nil
  end

  def test_custom_field_with_visible_set_to_false_should_validate_roles
    set_language_if_valid 'en'
    field = TimeEntryCustomField.new(:name => 'Field', :field_format => 'string', :visible => false)
    assert !field.save
    assert_include "Roles cannot be blank", field.errors.full_messages
    field.role_ids = [1, 2]
    assert field.save
  end

  def test_changing_visible_to_true_should_clear_roles
    field = TimeEntryCustomField.create!(:name => 'Field', :field_format => 'string', :visible => false, :role_ids => [1, 2])
    assert_equal 2, field.roles.count

    field.visible = true
    field.save!
    assert_equal 0, field.roles.count
  end

  def test_safe_attributes_should_include_only_custom_fields_visible_to_user
    cf1 = TimeEntryCustomField.create!(:name => 'Visible field',
                                       :field_format => 'string',
                                       :visible => false, :role_ids => [1])
    cf2 = TimeEntryCustomField.create!(:name => 'Non visible field',
                                       :field_format => 'string',
                                       :visible => false, :role_ids => [3])
    user = User.find(2)
    time_entry = TimeEntry.new(:issue_id => 1)

    time_entry.send :safe_attributes=, {'custom_field_values' => {
      cf1.id.to_s => 'value1',
      cf2.id.to_s => 'value2'
    }}, user

    assert_equal 'value1', time_entry.custom_field_value(cf1)
    assert_nil time_entry.custom_field_value(cf2)

    time_entry.send :safe_attributes=, {'custom_fields' => [
      {'id' => cf1.id.to_s, 'value' => 'valuea'},
      {'id' => cf2.id.to_s, 'value' => 'valueb'}
    ]}, user

    assert_equal 'valuea', time_entry.custom_field_value(cf1)
    assert_nil time_entry.custom_field_value(cf2)
  end

  def test_safe_attributes_should_keep_values_of_custom_fields_not_visible_to_user
    field = TimeEntryCustomField.create!(:name => 'Non visible field',
                                         :field_format => 'string',
                                         :visible => false, :role_ids => [1])
    time_entry = TimeEntry.generate!(:project_id => 1, :user_id => 3, :author_id => 3)
    time_entry.custom_field_values = {field.id.to_s => 'Foo'}
    time_entry.save!

    time_entry.send :safe_attributes=, {
      'comments' => 'Updated',
      'custom_field_values' => {field.id.to_s => 'Bar'}
    }, User.find(3)
    time_entry.save!

    assert_equal 'Foo', time_entry.reload.custom_field_value(field)
  end

  def test_required_custom_field_not_visible_to_user_should_not_be_validated
    TimeEntryCustomField.create!(:name => 'Non visible field',
                                 :field_format => 'string', :is_required => true,
                                 :visible => false, :role_ids => [1])
    User.current = User.find(3)
    time_entry = TimeEntry.new(:project_id => 1, :user => User.current, :author => User.current)
    time_entry.safe_attributes = {'hours' => '1', 'spent_on' => '2026-10-01', 'activity_id' => '9'}

    assert time_entry.save
  end
end
