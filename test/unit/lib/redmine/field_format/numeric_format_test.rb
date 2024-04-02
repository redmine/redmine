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

class Redmine::NumericFieldFormatTest < ActionView::TestCase
  fixtures :projects, :users, :issue_statuses, :enumerations,
           :trackers, :projects_trackers, :roles, :member_roles,
           :members, :enabled_modules

  def setup
    User.current = nil
  end

  def test_integer_field_with_url_pattern_should_format_as_link
    field = IssueCustomField.new(:field_format => 'int', :url_pattern => 'http://foo/%value%')
    custom_value = CustomValue.new(:custom_field => field, :customized => Issue.new, :value => "3")

    assert_equal 3, field.format.formatted_custom_value(self, custom_value, false)
    assert_equal '<a href="http://foo/3" class="external">3</a>', field.format.formatted_custom_value(self, custom_value, true)
  end

  def test_float_field_value_should_validate_when_given_with_various_separator
    field = IssueCustomField.generate!(field_format: 'float')
    issue = Issue.generate!(tracker: Tracker.find(1), status: IssueStatus.find(1), priority: IssuePriority.find(6))
    to_test = {'en' => '3.33', 'de' => '3,33'}
    to_test.each do |locale, expected|
      with_locale locale do
        assert field.format.validate_single_value(field, expected, issue)
      end
    end
  end

  def test_float_field_should_format_with_various_locale_separator
    field = IssueCustomField.generate!(field_format: 'float')
    issue = Issue.generate!(tracker: Tracker.find(1), status: IssueStatus.find(1), priority: IssuePriority.find(6))
    issue.custom_field_values = { field.id => '1234.56' }
    issue.save!
    to_test = {'en' => '1234.56', 'de' => '1234,56'}
    to_test.each do |locale, expected|
      with_locale locale do
        assert_equal expected, format_object(issue.reload.custom_field_values.last, false)
      end
    end
  end
end
