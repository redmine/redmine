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

class Redmine::UserFieldFormatTest < ActionView::TestCase
  def setup
    User.current = nil
  end

  def test_user_role_should_reject_blank_values
    field = IssueCustomField.new(:name => 'Foo', :field_format => 'user', :user_role => ["1", ""])
    field.save!
    assert_equal ["1"], field.user_role
  end

  def test_existing_values_should_be_valid
    field = IssueCustomField.create!(:name => 'Foo', :field_format => 'user', :is_for_all => true, :trackers => Tracker.all)
    project = Project.generate!
    user = User.generate!
    User.add_to_project(user, project, Role.find_by_name('Manager'))
    issue = Issue.generate!(:project_id => project.id, :tracker_id => 1, :custom_field_values => {field.id => user.id})

    field.user_role = [Role.find_by_name('Developer').id]
    field.save!

    issue = Issue.order(id: :desc).first
    assert_include [user.name, user.id.to_s], field.possible_custom_value_options(issue.custom_value_for(field))
    assert issue.valid?
  end

  def test_non_existing_values_should_be_invalid
    field = IssueCustomField.create!(:name => 'Foo', :field_format => 'user', :is_for_all => true, :trackers => Tracker.all)
    project = Project.generate!
    user = User.generate!
    User.add_to_project(user, project, Role.find_by_name('Developer'))

    field.user_role = [Role.find_by_name('Manager').id]
    field.save!

    issue = Issue.new(:project_id => project.id, :tracker_id => 1, :custom_field_values => {field.id => user.id})
    assert_not_include [user.name, user.id.to_s], field.possible_custom_value_options(issue.custom_value_for(field))
    assert_equal false, issue.valid?
    assert_include "Foo #{::I18n.t('activerecord.errors.messages.inclusion')}", issue.errors.full_messages.first
  end

  def test_possible_values_options_should_return_project_members
    field = IssueCustomField.new(:field_format => 'user')
    project = Project.find(1)

    assert_equal ['Dave Lopper', 'John Smith'], field.possible_values_options(project).map(&:first)
  end

  def test_possible_values_options_should_return_project_members_with_selected_role
    field = IssueCustomField.new(:field_format => 'user', :possible_principals => 'user_group', :user_role => ["2"])
    project = Project.find(5)

    assert_equal ['User Misc', 'A Team'], field.possible_values_options(project).map(&:first)
  end

  def test_possible_values_options_should_return_project_members_and_me_if_logged_in
    ::I18n.locale = 'en'
    User.current = User.find(2)
    field = IssueCustomField.new(:field_format => 'user')
    project = Project.find(1)

    assert_equal ['<< me >>', 'Dave Lopper', 'John Smith'], field.possible_values_options(project).map(&:first)
  end

  def test_possible_values_options_for_multiple_custom_field_should_not_include_me
    User.current = User.find(2)
    field = IssueCustomField.new(:field_format => 'user', :multiple => true)
    project = Project.find(1)

    assert_equal ['Dave Lopper', 'John Smith'], field.possible_values_options(project).map(&:first)
  end

  def test_value_from_keyword_should_return_user_id
    field = IssueCustomField.new(:field_format => 'user')
    project = Project.find(1)

    assert_equal 2, field.value_from_keyword('jsmith', project)
    assert_equal 3, field.value_from_keyword('Dave Lopper', project)
    assert_nil field.value_from_keyword('Unknown User', project)
  end

  def test_value_from_keyword_for_multiple_custom_field_should_return_enumeration_ids
    field = IssueCustomField.new(:field_format => 'user', :multiple => true)
    project = Project.find(1)

    assert_equal [2, 3], field.value_from_keyword('jsmith, Dave Lopper', project)
    assert_equal [2], field.value_from_keyword('jsmith', project)
    assert_equal [], field.value_from_keyword('Unknown User', project)
  end

  def test_group_value_should_be_invalid_when_groups_are_not_allowed
    field = IssueCustomField.create!(:name => 'Foo', :field_format => 'user', :is_for_all => true, :trackers => Tracker.all)
    issue = Issue.new(:project_id => 5, :tracker_id => 1, :author_id => 2, :subject => 'Test',
                      :custom_field_values => {field.id => '10'})

    assert_equal false, issue.valid?
    assert_include "Foo #{::I18n.t('activerecord.errors.messages.inclusion')}", issue.errors.full_messages.first
  end

  def test_existing_group_value_should_remain_valid_after_disallowing_groups
    field = IssueCustomField.create!(:name => 'Foo', :field_format => 'user', :possible_principals => 'user_group',
                                     :is_for_all => true, :trackers => Tracker.all)
    issue = Issue.generate!(:project_id => 5, :tracker_id => 1, :custom_field_values => {field.id => '10'})

    field.update!(:possible_principals => 'user')
    issue.reload
    assert issue.valid?
    assert_equal 'A Team', field.format.formatted_value(self, field, issue.custom_field_value(field), issue).to_s
  end

  def test_edit_tag_with_groups_only_should_not_use_optgroups
    field = IssueCustomField.new(:field_format => 'user', :possible_principals => 'group', :is_required => false)
    value = CustomFieldValue.new(:custom_field => field, :customized => Issue.new(:project_id => 5))

    tag = field.format.edit_tag(self, 'abc', 'xyz', value)
    assert_select_in tag, 'select[id=abc][name=xyz]' do
      assert_select 'optgroup', 0
      assert_select 'select > option[value="10"]', :text => 'A Team'
      assert_select 'option[value="2"]', 0
    end
  end

  def test_edit_tag_with_groups_should_group_users_and_groups_in_optgroups
    set_language_if_valid 'en'
    User.current = User.find(2)
    field = IssueCustomField.new(:field_format => 'user', :possible_principals => 'user_group', :is_required => false)
    value = CustomFieldValue.new(:custom_field => field, :customized => Issue.new(:project_id => 5))

    tag = field.format.edit_tag(self, 'abc', 'xyz', value)
    assert_select_in tag, 'select[id=abc][name=xyz]' do
      assert_select 'option', :text => '<< me >>', :count => 1
      assert_select 'optgroup[label="Users"] option[value="2"]', :text => 'John Smith'
      assert_select 'optgroup[label="Groups"] option[value="10"]', :text => 'A Team'
    end
  end

  def test_bulk_edit_tag_with_groups_should_group_users_and_groups_in_optgroups
    set_language_if_valid 'en'
    field = IssueCustomField.new(:field_format => 'user', :possible_principals => 'user_group', :is_required => false)
    issues = [Issue.new(:project_id => 5), Issue.new(:project_id => 5)]

    tag = field.format.bulk_edit_tag(self, 'abc', 'xyz', field, issues, '')
    assert_select_in tag, 'select[name=xyz]' do
      assert_select 'optgroup[label="Users"] option[value="2"]', :text => 'John Smith'
      assert_select 'optgroup[label="Groups"] option[value="10"]', :text => 'A Team'
    end
  end
end
