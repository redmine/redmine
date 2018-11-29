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

class Redmine::VersionFieldFormatTest < ActionView::TestCase
  fixtures :projects, :versions, :trackers,
           :roles, :users, :members, :member_roles,
           :issue_statuses, :issue_categories, :issue_relations, :workflows,
           :enumerations

  def setup
    super
    User.current = nil
  end

  def test_version_status_should_reject_blank_values
    field = IssueCustomField.new(:name => 'Foo', :field_format => 'version', :version_status => ["open", ""])
    field.save!
    assert_equal ["open"], field.version_status
  end

  def test_existing_values_should_be_valid
    field = IssueCustomField.create!(:name => 'Foo', :field_format => 'version', :is_for_all => true, :trackers => Tracker.all)
    project = Project.generate!
    version = Version.generate!(:project => project, :status => 'open')
    issue = Issue.generate!(:project_id => project.id, :tracker_id => 1, :custom_field_values => {field.id => version.id})

    field.version_status = ["open"]
    field.save!

    issue = Issue.order('id DESC').first
    assert_include [version.name, version.id.to_s], field.possible_custom_value_options(issue.custom_value_for(field))
    assert issue.valid?
  end

  def test_not_existing_values_should_be_invalid
    field = IssueCustomField.create!(:name => 'Foo', :field_format => 'version', :is_for_all => true, :trackers => Tracker.all)
    project = Project.generate!
    version = Version.generate!(:project => project, :status => 'closed')

    field.version_status = ["open"]
    field.save!

    issue = Issue.new(:project_id => project.id, :tracker_id => 1, :custom_field_values => {field.id => version.id})
    assert_not_include [version.name, version.id.to_s], field.possible_custom_value_options(issue.custom_value_for(field))
    assert_equal false, issue.valid?
    assert_include "Foo #{::I18n.t('activerecord.errors.messages.inclusion')}", issue.errors.full_messages.first
  end

  def test_possible_values_options_should_return_project_versions
    field = IssueCustomField.new(:field_format => 'version')
    project = Project.find(1)
    expected = project.shared_versions.sort.map(&:name)

    assert_equal expected, field.possible_values_options(project).map(&:first)
  end
 
  def test_possible_values_options_should_return_system_shared_versions_without_project
    field = IssueCustomField.new(:field_format => 'version')
    version = Version.generate!(:project => Project.find(1), :status => 'open', :sharing => 'system')

    expected = Version.visible.where(:sharing => 'system').sort.map(&:name)
    assert_include version.name, expected
    assert_equal expected, field.possible_values_options.map(&:first)
  end

  def test_possible_values_options_should_return_project_versions_with_selected_status
    field = IssueCustomField.new(:field_format => 'version', :version_status => ["open"])
    project = Project.find(1)
    expected = project.shared_versions.sort.select {|v| v.status == "open"}.map(&:name)

    assert_equal expected, field.possible_values_options(project).map(&:first)
  end

  def test_cast_value_should_not_raise_error_when_array_contains_value_casted_to_nil
    field = IssueCustomField.new(:field_format => 'version')
    assert_nothing_raised do
      field.cast_value([1,2, 42])
    end
  end

  def test_query_filter_options_should_include_versions_with_any_status
    field = IssueCustomField.new(:field_format => 'version', :version_status => ["open"])
    project = Project.find(1)
    version = Version.generate!(:project => project, :status => 'locked')
    query = Query.new(:project => project)

    full_name = "#{version.project} - #{version.name}"
    assert_not_include full_name, field.possible_values_options(project).map(&:first)
    assert_include full_name, field.query_filter_options(query)[:values].call.map(&:first)
  end

  def test_query_filter_options_should_include_version_status_for_grouping
    field = IssueCustomField.new(:field_format => 'version', :version_status => ["open"])
    project = Project.find(1)
    version = Version.generate!(:project => project, :status => 'locked')
    query = Query.new(:project => project)

    full_name = "#{version.project} - #{version.name}"
    assert_include [full_name, version.id.to_s, l(:version_status_locked)],
      field.query_filter_options(query)[:values].call
  end
end
