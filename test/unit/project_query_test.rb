# frozen_string_literal: true

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

class ProjectQueryTest < ActiveSupport::TestCase
  fixtures :projects, :users,
           :members, :roles, :member_roles,
           :issue_categories, :enumerations,
           :groups_users,
           :enabled_modules,
           :custom_fields, :custom_values

  include Redmine::I18n

  def test_filter_values_be_arrays
    q = ProjectQuery.new
    assert_nil q.project

    q.available_filters.each do |name, filter|
      values = filter.values
      assert (values.nil? || values.is_a?(Array)),
             "#values for #{name} filter returned a #{values.class.name}"
    end
  end

  def test_project_statuses_filter_should_return_project_statuses
    set_language_if_valid 'en'
    query = ProjectQuery.new(:name => '_')
    query.filters = {'status' => {:operator => '=', :values => []}}
    values = query.available_filters['status'][:values]
    assert_equal ['active', 'closed'], values.map(&:first)
    assert_equal ['1', '5'], values.map(&:second)
  end

  def test_default_columns
    q = ProjectQuery.new
    assert q.columns.any?
    assert q.inline_columns.any?
    assert q.block_columns.empty?
  end

  def test_available_columns_should_include_project_custom_fields
    query = ProjectQuery.new
    assert_include :cf_3, query.available_columns.map(&:name)
  end
end
