# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

class TimeEntryQuery < Query

  self.queried_class = TimeEntry

  self.available_columns = [
    QueryColumn.new(:project, :sortable => "#{Project.table_name}.name", :groupable => true),
    QueryColumn.new(:spent_on, :sortable => ["#{TimeEntry.table_name}.spent_on", "#{TimeEntry.table_name}.created_on"], :default_order => 'desc', :groupable => true),
    QueryColumn.new(:tweek, :sortable => ["#{TimeEntry.table_name}.spent_on", "#{TimeEntry.table_name}.created_on"], :caption => l(:label_week)),
    QueryColumn.new(:user, :sortable => lambda {User.fields_for_order_statement}, :groupable => true),
    QueryColumn.new(:activity, :sortable => "#{TimeEntryActivity.table_name}.position", :groupable => true),
    QueryColumn.new(:issue, :sortable => "#{Issue.table_name}.id"),
    QueryColumn.new(:comments),
    QueryColumn.new(:hours, :sortable => "#{TimeEntry.table_name}.hours"),
  ]

  def initialize(attributes=nil, *args)
    super attributes
    self.filters ||= {}
    add_filter('spent_on', '*') unless filters.present?
  end

  def initialize_available_filters
    add_available_filter "spent_on", :type => :date_past

    principals = []
    if project
      principals += project.principals.visible.sort
      unless project.leaf?
        subprojects = project.descendants.visible.to_a
        if subprojects.any?
          add_available_filter "subproject_id",
            :type => :list_subprojects,
            :values => subprojects.collect{|s| [s.name, s.id.to_s] }
          principals += Principal.member_of(subprojects).visible
        end
      end
    else
      if all_projects.any?
        # members of visible projects
        principals += Principal.member_of(all_projects).visible
        # project filter
        project_values = []
        if User.current.logged? && User.current.memberships.any?
          project_values << ["<< #{l(:label_my_projects).downcase} >>", "mine"]
        end
        project_values += all_projects_values
        add_available_filter("project_id",
          :type => :list, :values => project_values
        ) unless project_values.empty?
      end
    end
    principals.uniq!
    principals.sort!
    users = principals.select {|p| p.is_a?(User)}

    users_values = []
    users_values << ["<< #{l(:label_me)} >>", "me"] if User.current.logged?
    users_values += users.collect{|s| [s.name, s.id.to_s] }
    add_available_filter("user_id",
      :type => :list_optional, :values => users_values
    ) unless users_values.empty?

    activities = (project ? project.activities : TimeEntryActivity.shared)
    add_available_filter("activity_id",
      :type => :list, :values => activities.map {|a| [a.name, a.id.to_s]}
    ) unless activities.empty?

    add_available_filter "comments", :type => :text
    add_available_filter "hours", :type => :float

    add_custom_fields_filters(TimeEntryCustomField)
    add_associations_custom_fields_filters :project, :issue, :user
  end

  def available_columns
    return @available_columns if @available_columns
    @available_columns = self.class.available_columns.dup
    @available_columns += TimeEntryCustomField.visible.
                            map {|cf| QueryCustomFieldColumn.new(cf) }
    @available_columns += IssueCustomField.visible.
                            map {|cf| QueryAssociationCustomFieldColumn.new(:issue, cf) }
    @available_columns
  end

  def default_columns_names
    @default_columns_names ||= [:project, :spent_on, :user, :activity, :issue, :comments, :hours]
  end

  def results_scope(options={})
    order_option = [group_by_sort_order, options[:order]].flatten.reject(&:blank?)

    TimeEntry.visible.
      where(statement).
      order(order_option).
      joins(joins_for_order_statement(order_option.join(','))).
      includes(:activity).
      references(:activity)
  end

  def sql_for_activity_id_field(field, operator, value)
    condition_on_id = sql_for_field(field, operator, value, Enumeration.table_name, 'id')
    condition_on_parent_id = sql_for_field(field, operator, value, Enumeration.table_name, 'parent_id')
    ids = value.map(&:to_i).join(',')
    table_name = Enumeration.table_name
    if operator == '='
      "(#{table_name}.id IN (#{ids}) OR #{table_name}.parent_id IN (#{ids}))"
    else
      "(#{table_name}.id NOT IN (#{ids}) AND (#{table_name}.parent_id IS NULL OR #{table_name}.parent_id NOT IN (#{ids})))"
    end
  end

  # Accepts :from/:to params as shortcut filters
  def build_from_params(params)
    super
    if params[:from].present? && params[:to].present?
      add_filter('spent_on', '><', [params[:from], params[:to]])
    elsif params[:from].present?
      add_filter('spent_on', '>=', [params[:from]])
    elsif params[:to].present?
      add_filter('spent_on', '<=', [params[:to]])
    end
    self
  end
end
