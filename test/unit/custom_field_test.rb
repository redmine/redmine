# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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

class CustomFieldTest < ActiveSupport::TestCase
  fixtures :custom_fields

  def test_create
    field = UserCustomField.new(:name => 'Money money money', :field_format => 'float')
    assert field.save
  end

  def test_before_validation
    field = CustomField.new(:name => 'test_before_validation', :field_format => 'int')
    field.searchable = true
    assert field.save
    assert_equal false, field.searchable
    field.searchable = true
    assert field.save
    assert_equal false, field.searchable
  end

  def test_regexp_validation
    field = IssueCustomField.new(:name => 'regexp', :field_format => 'text', :regexp => '[a-z0-9')
    assert !field.save
    assert_equal I18n.t('activerecord.errors.messages.invalid'),
                 field.errors[:regexp].to_s
    field.regexp = '[a-z0-9]'
    assert field.save
  end

  def test_possible_values_should_accept_an_array
    field = CustomField.new
    field.possible_values = ["One value", ""]
    assert_equal ["One value"], field.possible_values
  end

  def test_possible_values_should_accept_a_string
    field = CustomField.new
    field.possible_values = "One value"
    assert_equal ["One value"], field.possible_values
  end

  def test_possible_values_should_accept_a_multiline_string
    field = CustomField.new
    field.possible_values = "One value\nAnd another one  \r\n \n"
    assert_equal ["One value", "And another one"], field.possible_values
  end

  def test_destroy
    field = CustomField.find(1)
    assert field.destroy
  end

  def test_new_subclass_instance_should_return_an_instance
    f = CustomField.new_subclass_instance('IssueCustomField')
    assert_kind_of IssueCustomField, f
  end

  def test_new_subclass_instance_should_set_attributes
    f = CustomField.new_subclass_instance('IssueCustomField', :name => 'Test')
    assert_kind_of IssueCustomField, f
    assert_equal 'Test', f.name
  end

  def test_new_subclass_instance_with_invalid_class_name_should_return_nil
    assert_nil CustomField.new_subclass_instance('WrongClassName')
  end

  def test_new_subclass_instance_with_non_subclass_name_should_return_nil
    assert_nil CustomField.new_subclass_instance('Project')
  end
end
