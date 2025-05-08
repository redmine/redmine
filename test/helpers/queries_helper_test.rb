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

class QueriesHelperTest < Redmine::HelperTest
  include QueriesHelper

  def test_filters_options_for_select_should_have_a_blank_option
    options = filters_options_for_select(IssueQuery.new)
    assert_select_in options, 'option[value=""]'
  end

  def test_filters_options_for_select_should_not_group_regular_filters
    with_locale 'en' do
      options = filters_options_for_select(IssueQuery.new)
      assert_select_in options, 'optgroup option[value=status_id]', 0
      assert_select_in options, 'option[value=status_id]', :text => 'Status'
    end
  end

  def test_filters_options_for_select_should_group_date_filters
    with_locale 'en' do
      options = filters_options_for_select(IssueQuery.new)
      assert_select_in options, 'optgroup[label=?]', 'Date', 1
      assert_select_in options, 'optgroup > option[value=due_date]', :text => 'Due date'
    end
  end

  def test_filters_options_for_select_should_not_group_only_one_date_filter
    with_locale 'en' do
      options = filters_options_for_select(TimeEntryQuery.new)
      assert_select_in options, 'option[value=spent_on]'
      assert_select_in options, 'optgroup[label=?]', 'Date', 0
      assert_select_in options, 'optgroup option[value=spent_on]', 0
    end
  end

  def test_filters_options_for_select_should_group_relations_filters
    with_locale 'en' do
      options = filters_options_for_select(IssueQuery.new)
      assert_select_in options, 'optgroup[label=?]', 'Relations', 1
      assert_select_in options, 'optgroup[label=?] > option', 'Relations', 11
      assert_select_in options, 'optgroup > option[value=relates]', :text => 'Related to'
    end
  end

  def test_filters_options_for_select_should_group_associations_filters
    CustomField.delete_all
    cf1 = ProjectCustomField.create!(:name => 'Foo', :field_format => 'string', :is_filter => true)
    cf2 = ProjectCustomField.create!(:name => 'Bar', :field_format => 'string', :is_filter => true)

    with_locale 'en' do
      options = filters_options_for_select(IssueQuery.new)
      assert_select_in options, 'optgroup[label=?]', 'Project', 1
      assert_select_in options, 'optgroup[label=?] > option', 'Project', 3
      assert_select_in options, 'optgroup > option[value=?]', "project.cf_#{cf1.id}", :text => "Project's Foo"
    end
  end

  def test_filters_options_for_select_should_group_text_filters
    with_locale 'en' do
      options = filters_options_for_select(IssueQuery.new)
      assert_select_in options, 'optgroup[label=?]', 'Text', 1
      assert_select_in options, 'optgroup > option[value=subject]', :text => 'Subject'
      assert_select_in options, 'optgroup > option[value=cf_2]', :text => 'Searchable field'
      assert_select_in options, 'optgroup > option:last-of-type[value=any_searchable]', :text => 'Any searchable text'
    end
  end

  def test_query_to_csv_should_translate_boolean_custom_field_values
    f = IssueCustomField.generate!(:field_format => 'bool', :name => 'Boolean', :is_for_all => true, :trackers => Tracker.all)
    issues = [
      Issue.generate!(:project_id => 1, :tracker_id => 1, :custom_field_values => {f.id.to_s => '0'}),
      Issue.generate!(:project_id => 1, :tracker_id => 1, :custom_field_values => {f.id.to_s => '1'})
    ]

    with_locale 'fr' do
      csv = query_to_csv(issues, IssueQuery.new(:column_names => ['id', "cf_#{f.id}"]))
      assert_include "Oui", csv
      assert_include "Non", csv
    end
  end

  def test_filters_options_for_select_should_group_custom_field_relations
    i_cf = IssueCustomField.generate!(field_format: 'user', name: 'User', is_for_all: true, trackers: Tracker.all, is_filter: true)
    u_cf = UserCustomField.find(4)
    u_cf.is_filter = true
    u_cf.save

    options = filters_options_for_select(IssueQuery.new)

    assert_select_in options, 'option[value=?]', "cf_#{i_cf.id}.cf_#{u_cf.id}", text: "User's Phone number"
    assert_select_in options, 'optgroup[label=?]', 'User', 1
  end
end
