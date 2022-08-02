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

class ProjectQuery < Query
  self.queried_class = Project
  self.view_permission = :search_project

  validate do |query|
    # project must be blank for ProjectQuery
    errors.add(:project_id, :exclusion) if query.project_id.present?
  end

  self.available_columns = [
    QueryColumn.new(:name, :sortable => "#{Project.table_name}.name"),
    QueryColumn.new(:status, :sortable => "#{Project.table_name}.status"),
    QueryColumn.new(:short_description, :sortable => "#{Project.table_name}.description", :caption => :field_description),
    QueryColumn.new(:homepage, :sortable => "#{Project.table_name}.homepage"),
    QueryColumn.new(:identifier, :sortable => "#{Project.table_name}.identifier"),
    QueryColumn.new(:parent_id, :sortable => "#{Project.table_name}.lft ASC", :default_order => 'desc', :caption => :field_parent),
    QueryColumn.new(:is_public, :sortable => "#{Project.table_name}.is_public", :groupable => true),
    QueryColumn.new(:created_on, :sortable => "#{Project.table_name}.created_on", :default_order => 'desc')
  ]

  def self.default(project: nil, user: User.current)
    if user&.logged? && (query_id = user.pref.default_project_query).present?
      query = find_by(id: query_id)
      return query if query&.visible?
    end
    if (query_id = Setting.default_project_query).present?
      query = find_by(id: query_id)
      return query if query&.visibility == VISIBILITY_PUBLIC
    end
    nil
  end

  def initialize(attributes=nil, *args)
    super attributes
    self.filters ||= {'status' => {:operator => "=", :values => ['1']}}
  end

  def initialize_available_filters
    add_available_filter(
      "status",
      :type => :list, :values => lambda {project_statuses_values}
    )
    add_available_filter(
      "id",
      :type => :list, :values => lambda {project_values}, :label => :field_project
    )
    add_available_filter "name", :type => :text
    add_available_filter "description", :type => :text
    add_available_filter(
      "parent_id",
      :type => :list_subprojects, :values => lambda {project_values}, :label => :field_parent
    )
    add_available_filter(
      "is_public",
      :type => :list,
      :values => [[l(:general_text_yes), "1"], [l(:general_text_no), "0"]]
    )
    add_available_filter "created_on", :type => :date_past
    add_custom_fields_filters(project_custom_fields)
  end

  def available_columns
    return @available_columns if @available_columns

    @available_columns = self.class.available_columns.dup
    @available_columns += project_custom_fields.visible.
                            map {|cf| QueryCustomFieldColumn.new(cf)}
    @available_columns
  end

  def available_display_types
    ['board', 'list']
  end

  def default_columns_names
    @default_columns_names = Setting.project_list_defaults.symbolize_keys[:column_names].map(&:to_sym)
  end

  def default_display_type
    Setting.project_list_display_type
  end

  def default_sort_criteria
    [[]]
  end

  def base_scope
    Project.visible.where(statement)
  end

  def results_scope(options={})
    order_option = [group_by_sort_order, (options[:order] || sort_clause)].flatten.reject(&:blank?)

    order_option << "#{Project.table_name}.lft ASC"
    scope = base_scope.
      order(order_option).
      joins(joins_for_order_statement(order_option.join(',')))

    if has_custom_field_column?
      scope = scope.preload(:custom_values)
    end

    if has_column?(:parent_id)
      scope = scope.preload(:parent)
    end

    scope
  end
end
