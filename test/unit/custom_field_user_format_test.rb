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

require File.expand_path('../../test_helper', __FILE__)

class CustomFieldUserFormatTest < ActiveSupport::TestCase
  fixtures :custom_fields, :projects, :members, :users, :member_roles, :trackers, :issues

  def setup
    @field = IssueCustomField.create!(:name => 'Tester', :field_format => 'user')
  end

  def test_possible_values_options_with_no_arguments
    assert_equal [], @field.possible_values_options
    assert_equal [], @field.possible_values_options(nil)
  end

  def test_possible_values_options_with_project_resource
    project = Project.find(1)
    possible_values_options = @field.possible_values_options(project.issues.first)
    assert possible_values_options.any?
    assert_equal project.users.sort.map {|u| [u.name, u.id.to_s]}, possible_values_options
  end

  def test_possible_values_options_with_array
    projects = Project.find([1, 2])
    possible_values_options = @field.possible_values_options(projects)
    assert possible_values_options.any?
    assert_equal (projects.first.users & projects.last.users).sort.map {|u| [u.name, u.id.to_s]}, possible_values_options
  end

  def test_possible_custom_value_options_should_not_include_locked_users
    custom_value = CustomValue.new(:customized => Issue.find(1), :custom_field => @field)
    assert_include '2', @field.possible_custom_value_options(custom_value).map(&:last)

    assert User.find(2).lock!
    assert_not_include '2', @field.possible_custom_value_options(custom_value).map(&:last)
  end

  def test_possible_custom_value_options_should_include_user_that_was_assigned_to_the_custom_value
    user = User.generate!
    custom_value = CustomValue.new(:customized => Issue.find(1), :custom_field => @field)
    assert_not_include user.id.to_s, @field.possible_custom_value_options(custom_value).map(&:last)

    custom_value.value = user.id
    custom_value.save!
    assert_include user.id.to_s, @field.possible_custom_value_options(custom_value).map(&:last)
  end

  def test_cast_blank_value
    assert_nil @field.cast_value(nil)
    assert_nil @field.cast_value("")
  end

  def test_cast_valid_value
    user = @field.cast_value("2")
    assert_kind_of User, user
    assert_equal User.find(2), user
  end

  def test_cast_invalid_value
    assert_nil @field.cast_value("187")
  end
end
