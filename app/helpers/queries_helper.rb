# encoding: utf-8
#
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

module QueriesHelper
  include ApplicationHelper

  def filters_options_for_select(query)
    ungrouped = []
    grouped = {}
    query.available_filters.map do |field, field_options|
      if [:tree, :relation].include?(field_options[:type]) 
        group = :label_related_issues
      elsif field =~ /^(.+)\./
        # association filters
        group = "field_#{$1}"
      elsif %w(member_of_group assigned_to_role).include?(field)
        group = :field_assigned_to
      elsif field_options[:type] == :date_past || field_options[:type] == :date
        group = :label_date
      end
      if group
        (grouped[group] ||= []) << [field_options[:name], field]
      else
        ungrouped << [field_options[:name], field]
      end
    end
    # Don't group dates if there's only one (eg. time entries filters)
    if grouped[:label_date].try(:size) == 1 
      ungrouped << grouped.delete(:label_date).first
    end
    s = options_for_select([[]] + ungrouped)
    if grouped.present?
      localized_grouped = grouped.map {|k,v| [l(k), v]}
      s << grouped_options_for_select(localized_grouped)
    end
    s
  end

  def query_filters_hidden_tags(query)
    tags = ''.html_safe
    query.filters.each do |field, options|
      tags << hidden_field_tag("f[]", field, :id => nil)
      tags << hidden_field_tag("op[#{field}]", options[:operator], :id => nil)
      options[:values].each do |value|
        tags << hidden_field_tag("v[#{field}][]", value, :id => nil)
      end
    end
    tags
  end

  def query_columns_hidden_tags(query)
    tags = ''.html_safe
    query.columns.each do |column|
      tags << hidden_field_tag("c[]", column.name, :id => nil)
    end
    tags
  end

  def query_hidden_tags(query)
    query_filters_hidden_tags(query) + query_columns_hidden_tags(query)
  end

  def available_block_columns_tags(query)
    tags = ''.html_safe
    query.available_block_columns.each do |column|
      tags << content_tag('label', check_box_tag('c[]', column.name.to_s, query.has_column?(column), :id => nil) + " #{column.caption}", :class => 'inline')
    end
    tags
  end

  def available_totalable_columns_tags(query)
    tags = ''.html_safe
    query.available_totalable_columns.each do |column|
      tags << content_tag('label', check_box_tag('t[]', column.name.to_s, query.totalable_columns.include?(column), :id => nil) + " #{column.caption}", :class => 'inline')
    end
    tags
  end

  def query_available_inline_columns_options(query)
    (query.available_inline_columns - query.columns).reject(&:frozen?).collect {|column| [column.caption, column.name]}
  end

  def query_selected_inline_columns_options(query)
    (query.inline_columns & query.available_inline_columns).reject(&:frozen?).collect {|column| [column.caption, column.name]}
  end

  def render_query_columns_selection(query, options={})
    tag_name = (options[:name] || 'c') + '[]'
    render :partial => 'queries/columns', :locals => {:query => query, :tag_name => tag_name}
  end

  def render_query_totals(query)
    return unless query.totalable_columns.present?
    totals = query.totalable_columns.map do |column|
      total_tag(column, query.total_for(column))
    end
    content_tag('p', totals.join(" ").html_safe, :class => "query-totals")
  end

  def total_tag(column, value)
    label = content_tag('span', "#{column.caption}:")
    value = content_tag('span', format_object(value), :class => 'value')
    content_tag('span', label + " " + value, :class => "total-for-#{column.name.to_s.dasherize}")
  end

  def column_header(column)
    column.sortable ? sort_header_tag(column.name.to_s, :caption => column.caption,
                                                        :default_order => column.default_order) :
                      content_tag('th', h(column.caption))
  end

  def column_content(column, issue)
    value = column.value_object(issue)
    if value.is_a?(Array)
      value.collect {|v| column_value(column, issue, v)}.compact.join(', ').html_safe
    else
      column_value(column, issue, value)
    end
  end
  
  def column_value(column, issue, value)
    case column.name
    when :id
      link_to value, issue_path(issue)
    when :subject
      link_to value, issue_path(issue)
    when :parent
      value ? (value.visible? ? link_to_issue(value, :subject => false) : "##{value.id}") : ''
    when :description
      issue.description? ? content_tag('div', textilizable(issue, :description), :class => "wiki") : ''
    when :done_ratio
      progress_bar(value)
    when :relations
      content_tag('span',
        value.to_s(issue) {|other| link_to_issue(other, :subject => false, :tracker => false)}.html_safe,
        :class => value.css_classes_for(issue))
    else
      format_object(value)
    end
  end

  def csv_content(column, issue)
    value = column.value_object(issue)
    if value.is_a?(Array)
      value.collect {|v| csv_value(column, issue, v)}.compact.join(', ')
    else
      csv_value(column, issue, value)
    end
  end

  def csv_value(column, object, value)
    format_object(value, false) do |value|
      case value.class.name
      when 'Float'
        sprintf("%.2f", value).gsub('.', l(:general_csv_decimal_separator))
      when 'IssueRelation'
        value.to_s(object)
      when 'Issue'
        if object.is_a?(TimeEntry)
          "#{value.tracker} ##{value.id}: #{value.subject}"
        else
          value.id
        end
      else
        value
      end
    end
  end

  def query_to_csv(items, query, options={})
    options ||= {}
    columns = (options[:columns] == 'all' ? query.available_inline_columns : query.inline_columns)
    query.available_block_columns.each do |column|
      if options[column.name].present?
        columns << column
      end
    end

    Redmine::Export::CSV.generate do |csv|
      # csv header fields
      csv << columns.map {|c| c.caption.to_s}
      # csv lines
      items.each do |item|
        csv << columns.map {|c| csv_content(c, item)}
      end
    end
  end

  # Retrieve query from session or build a new query
  def retrieve_query
    if !params[:query_id].blank?
      cond = "project_id IS NULL"
      cond << " OR project_id = #{@project.id}" if @project
      @query = IssueQuery.where(cond).find(params[:query_id])
      raise ::Unauthorized unless @query.visible?
      @query.project = @project
      session[:query] = {:id => @query.id, :project_id => @query.project_id}
      sort_clear
    elsif api_request? || params[:set_filter] || session[:query].nil? || session[:query][:project_id] != (@project ? @project.id : nil)
      # Give it a name, required to be valid
      @query = IssueQuery.new(:name => "_")
      @query.project = @project
      @query.build_from_params(params)
      session[:query] = {:project_id => @query.project_id, :filters => @query.filters, :group_by => @query.group_by, :column_names => @query.column_names, :totalable_names => @query.totalable_names}
    else
      # retrieve from session
      @query = nil
      @query = IssueQuery.find_by_id(session[:query][:id]) if session[:query][:id]
      @query ||= IssueQuery.new(:name => "_", :filters => session[:query][:filters], :group_by => session[:query][:group_by], :column_names => session[:query][:column_names], :totalable_names => session[:query][:totalable_names])
      @query.project = @project
    end
  end

  def retrieve_query_from_session
    if session[:query]
      if session[:query][:id]
        @query = IssueQuery.find_by_id(session[:query][:id])
        return unless @query
      else
        @query = IssueQuery.new(:name => "_", :filters => session[:query][:filters], :group_by => session[:query][:group_by], :column_names => session[:query][:column_names], :totalable_names => session[:query][:totalable_names])
      end
      if session[:query].has_key?(:project_id)
        @query.project_id = session[:query][:project_id]
      else
        @query.project = @project
      end
      @query
    end
  end
end
