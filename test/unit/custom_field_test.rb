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

require File.expand_path('../../test_helper', __FILE__)

class CustomFieldTest < ActiveSupport::TestCase
  fixtures :custom_fields, :roles, :projects,
           :trackers, :issue_statuses,
           :issues, :users

  def setup
    User.current = nil
  end

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
    assert_include I18n.t('activerecord.errors.messages.invalid'),
                   field.errors[:regexp]
    field.regexp = '[a-z0-9]'
    assert field.save
  end

  def test_default_value_should_be_validated
    field = CustomField.new(:name => 'Test', :field_format => 'int')
    field.default_value = 'abc'
    assert !field.valid?
    field.default_value = '6'
    assert field.valid?
  end

  def test_default_value_should_not_be_validated_when_blank
    field = CustomField.new(:name => 'Test', :field_format => 'list',
                            :possible_values => ['a', 'b'], :is_required => true,
                            :default_value => '')
    assert field.valid?
  end

  def test_field_format_should_be_validated
    field = CustomField.new(:name => 'Test', :field_format => 'foo')
    assert !field.valid?
  end

  def test_field_format_validation_should_accept_formats_added_at_runtime
    Redmine::FieldFormat.add 'foobar', Class.new(Redmine::FieldFormat::Base)

    field = CustomField.new(:name => 'Some Custom Field', :field_format => 'foobar')
    assert field.valid?, 'field should be valid'
  ensure
    Redmine::FieldFormat.delete 'foobar'
  end

  def test_should_not_change_field_format_of_existing_custom_field
    field = CustomField.find(1)
    field.field_format = 'int'
    assert_equal 'list', field.field_format
  end

  def test_possible_values_should_accept_an_array
    field = CustomField.new
    field.possible_values = ["One value", ""]
    assert_equal ["One value"], field.possible_values
  end

  def test_possible_values_should_stringify_values
    field = CustomField.new
    field.possible_values = [1, 2]
    assert_equal ["1", "2"], field.possible_values
  end

  def test_possible_values_should_accept_a_string
    field = CustomField.new
    field.possible_values = "One value"
    assert_equal ["One value"], field.possible_values
  end

  def test_possible_values_should_return_utf8_encoded_strings
    field = CustomField.new
    s = "Value".b
    field.possible_values = s
    assert_equal [s], field.possible_values
    assert_equal 'UTF-8', field.possible_values.first.encoding.name
  end

  def test_possible_values_should_accept_a_multiline_string
    field = CustomField.new
    field.possible_values = "One value\nAnd another one  \r\n \n"
    assert_equal ["One value", "And another one"], field.possible_values
  end

  def test_possible_values_stored_as_binary_should_be_utf8_encoded
    field = CustomField.find(11)
    assert_kind_of Array, field.possible_values
    assert field.possible_values.size > 0
    field.possible_values.each do |value|
      assert_equal "UTF-8", value.encoding.name
    end
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

  def test_string_field_validation_with_blank_value
    f = CustomField.new(:field_format => 'string')

    assert f.valid_field_value?(nil)
    assert f.valid_field_value?('')

    f.is_required = true
    assert !f.valid_field_value?(nil)
    assert !f.valid_field_value?('')
  end

  def test_string_field_validation_with_min_and_max_lengths
    f = CustomField.new(:field_format => 'string', :min_length => 2, :max_length => 5)

    assert f.valid_field_value?(nil)
    assert f.valid_field_value?('')
    assert !f.valid_field_value?(' ')
    assert f.valid_field_value?('a' * 2)
    assert !f.valid_field_value?('a')
    assert !f.valid_field_value?('a' * 6)
  end

  def test_string_field_validation_with_regexp
    f = CustomField.new(:field_format => 'string', :regexp => '^[A-Z0-9]*$')

    assert f.valid_field_value?(nil)
    assert f.valid_field_value?('')
    assert !f.valid_field_value?(' ')
    assert f.valid_field_value?('ABC')
    assert !f.valid_field_value?('abc')
  end

  def test_date_field_validation
    f = CustomField.new(:field_format => 'date')

    assert f.valid_field_value?(nil)
    assert f.valid_field_value?('')
    assert !f.valid_field_value?(' ')
    assert f.valid_field_value?('1975-07-14')
    assert !f.valid_field_value?('1975-07-33')
    assert !f.valid_field_value?('abc')
  end

  def test_list_field_validation
    f = CustomField.new(:field_format => 'list', :possible_values => ['value1', 'value2'])

    assert f.valid_field_value?(nil)
    assert f.valid_field_value?('')
    assert !f.valid_field_value?(' ')
    assert f.valid_field_value?('value2')
    assert !f.valid_field_value?('abc')
  end

  def test_int_field_validation
    f = CustomField.new(:field_format => 'int')

    assert f.valid_field_value?(nil)
    assert f.valid_field_value?('')
    assert !f.valid_field_value?(' ')
    assert f.valid_field_value?('123')
    assert f.valid_field_value?(' 123 ')
    assert f.valid_field_value?('+123')
    assert f.valid_field_value?('-123')
    assert !f.valid_field_value?('6abc')
    assert f.valid_field_value?(123)
  end

  def test_float_field_validation
    f = CustomField.new(:field_format => 'float')

    assert f.valid_field_value?(nil)
    assert f.valid_field_value?('')
    assert !f.valid_field_value?(' ')
    assert f.valid_field_value?('11.2')
    assert f.valid_field_value?(' 11.2 ')
    assert f.valid_field_value?('-6.250')
    assert f.valid_field_value?('5')
    assert !f.valid_field_value?('6abc')
    assert f.valid_field_value?(11.2)
  end

  def test_multi_field_validation
    f = CustomField.new(:field_format => 'list', :multiple => 'true', :possible_values => ['value1', 'value2'])

    assert f.valid_field_value?(nil)
    assert f.valid_field_value?('')
    assert !f.valid_field_value?(' ')
    assert f.valid_field_value?([])
    assert f.valid_field_value?([nil])
    assert f.valid_field_value?([''])
    assert !f.valid_field_value?([' '])

    assert f.valid_field_value?('value2')
    assert !f.valid_field_value?('abc')

    assert f.valid_field_value?(['value2'])
    assert !f.valid_field_value?(['abc'])

    assert f.valid_field_value?(['', 'value2'])
    assert !f.valid_field_value?(['', 'abc'])

    assert f.valid_field_value?(['value1', 'value2'])
    assert !f.valid_field_value?(['value1', 'abc'])
  end

  def test_changing_multiple_to_false_should_delete_multiple_values
    field = ProjectCustomField.create!(:name => 'field', :field_format => 'list',
                                       :multiple => 'true',
                                       :possible_values => ['field1', 'field2'])
    other = ProjectCustomField.create!(:name => 'other', :field_format => 'list',
                                       :multiple => 'true',
                                       :possible_values => ['other1', 'other2'])
    item_with_multiple_values = Project.generate!(:custom_field_values =>
                                                   {field.id => ['field1', 'field2'],
                                                    other.id => ['other1', 'other2']})
    item_with_single_values = Project.generate!(:custom_field_values =>
                                                   {field.id => ['field1'],
                                                    other.id => ['other2']})
    assert_difference 'CustomValue.count', -1 do
      field.multiple = false
      field.save!
    end

    item_with_multiple_values = Project.find(item_with_multiple_values.id)
    assert_kind_of String, item_with_multiple_values.custom_field_value(field)
    assert_kind_of Array, item_with_multiple_values.custom_field_value(other)
    assert_equal 2, item_with_multiple_values.custom_field_value(other).size
  end

  def test_value_class_should_return_the_class_used_for_fields_values
    assert_equal User, CustomField.new(:field_format => 'user').value_class
    assert_equal Version, CustomField.new(:field_format => 'version').value_class
  end

  def test_value_class_should_return_nil_for_other_fields
    assert_nil CustomField.new(:field_format => 'text').value_class
    assert_nil CustomField.new.value_class
  end

  def test_value_from_keyword_for_list_custom_field
    field = CustomField.find(1)
    assert_equal 'PostgreSQL', field.value_from_keyword('postgresql', Issue.find(1))
  end

  def test_visibile_scope_with_admin_should_return_all_custom_fields
    admin = User.generate! {|user| user.admin = true}
    CustomField.delete_all
    fields = [
      CustomField.generate!(:visible => true),
      CustomField.generate!(:visible => false),
      CustomField.generate!(:visible => false, :role_ids => [1, 3]),
      CustomField.generate!(:visible => false, :role_ids => [1, 2]),
    ]

    assert_equal 4, CustomField.visible(admin).count
  end

  def test_visibile_scope_with_non_admin_user_should_return_visible_custom_fields
    CustomField.delete_all
    fields = [
      CustomField.generate!(:visible => true),
      CustomField.generate!(:visible => false),
      CustomField.generate!(:visible => false, :role_ids => [1, 3]),
      CustomField.generate!(:visible => false, :role_ids => [1, 2]),
    ]
    user = User.generate!
    User.add_to_project(user, Project.first, Role.find(3))

    assert_equal [fields[0], fields[2]], CustomField.visible(user).order("id").to_a
  end

  def test_visibile_scope_with_anonymous_user_should_return_visible_custom_fields
    CustomField.delete_all
    fields = [
      CustomField.generate!(:visible => true),
      CustomField.generate!(:visible => false),
      CustomField.generate!(:visible => false, :role_ids => [1, 3]),
      CustomField.generate!(:visible => false, :role_ids => [1, 2]),
    ]

    assert_equal [fields[0]], CustomField.visible(User.anonymous).order("id").to_a
  end

  def test_float_cast_blank_value_should_return_nil
    field = CustomField.new(:field_format => 'float')
    assert_nil field.cast_value(nil)
    assert_nil field.cast_value('')
  end

  def test_float_cast_valid_value_should_return_float
    field = CustomField.new(:field_format => 'float')
    assert_equal 12.0, field.cast_value('12')
    assert_equal 12.5, field.cast_value('12.5')
    assert_equal 12.5, field.cast_value('+12.5')
    assert_equal -12.5, field.cast_value('-12.5')
  end

  def test_project_custom_field_visibility
    project_field = ProjectCustomField.generate!(:visible => false, :field_format => 'list', :possible_values => %w[a b c])
    project = Project.find(3)
    project.custom_field_values = {project_field.id => 'a'}

    # Admins can find projects with the field
    with_current_user(User.find(1)) do
      assert_includes Project.where(project_field.visibility_by_project_condition), project
    end

    # The field is not visible to normal users
    with_current_user(User.find(2)) do
      refute_includes Project.where(project_field.visibility_by_project_condition), project
    end
  end

  def test_full_text_formatting?
    field = IssueCustomField.create!(:name => 'Long text', :field_format => 'text', :text_formatting => 'full')
    assert field.full_text_formatting?

    field2 = IssueCustomField.create!(:name => 'Another long text', :field_format => 'text')
    assert !field2.full_text_formatting?
  end

  def test_copy_from
    custom_field = CustomField.find(1)
    copy = CustomField.new.copy_from(custom_field)

    assert_nil copy.id
    assert_equal '', copy.name
    assert_nil copy.position
    (custom_field.attribute_names - ['id', 'name', 'position']).each do |attribute_name|
      assert_equal custom_field.send(attribute_name).to_s, copy.send(attribute_name).to_s
    end

    copy.name = 'Copy'
    assert copy.save
  end

  def test_copy_from_should_copy_enumerations
    custom_field = CustomField.create(:field_format => 'enumeration', :name => 'CustomField')
    custom_field.enumerations.build(:name => 'enumeration1', :position => 1)
    custom_field.enumerations.build(:name => 'enumeration2', :position => 2)
    assert custom_field.save

    copy = CustomField.new.copy_from(custom_field)
    copy.name = 'Copy'
    assert copy.save
    assert_equal ['enumeration1', 'enumeration2'], copy.enumerations.pluck(:name)
    assert_equal [1, 2], copy.enumerations.pluck(:position)
  end

  def test_copy_from_should_copy_roles
    %w(IssueCustomField TimeEntryCustomField ProjectCustomField VersionCustomField).each do |klass_name|
      klass = klass_name.constantize
      custom_field = klass.new(:name => klass_name, :role_ids => [1, 2, 3, 4, 5])
      copy = klass.new.copy_from(custom_field)
      assert_equal [1, 2, 3, 4, 5], copy.role_ids.sort
    end
  end

  def test_copy_from_should_copy_trackers
    issue_custom_field = IssueCustomField.new(:name => 'IssueCustomField', :tracker_ids => [1, 2, 3])
    copy = IssueCustomField.new.copy_from(issue_custom_field)
    assert_equal [1, 2, 3], copy.tracker_ids
  end

  def test_copy_from_should_copy_projects
    issue_custom_field = IssueCustomField.new(:name => 'IssueCustomField', :project_ids => [1, 2, 3, 4, 5, 6])
    copy = IssueCustomField.new.copy_from(issue_custom_field)
    assert_equal [1, 2, 3, 4, 5, 6], copy.project_ids
  end
end
