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

require 'redmine/export/csv'

module QueriesHelper
  include ApplicationHelper

  def filters_options_for_select(query)
    ungrouped = []
    grouped = {label_string: [], label_date: [], label_time_tracking: [], label_attachment: []}
    query.available_filters.map do |field, field_options|
      if /^cf_\d+\./.match?(field)
        group = (field_options[:through] || field_options[:field]).try(:name)
      elsif field =~ /^(.+)\./
        # association filters
        group = :"field_#{$1}"
      elsif field_options[:type] == :relation
        group = :label_relations
      elsif field_options[:type] == :tree
        group = query.is_a?(IssueQuery) ? :label_relations : nil
      elsif %w(member_of_group assigned_to_role).include?(field)
        group = :field_assigned_to
      elsif field_options[:type] == :date_past || field_options[:type] == :date
        group = :label_date
      elsif %w(estimated_hours spent_time).include?(field)
        group = :label_time_tracking
      elsif %w(attachment attachment_description).include?(field)
        group = :label_attachment
      elsif [:string, :text, :search].include?(field_options[:type])
        group = :label_string
      end
      if group
        (grouped[group] ||= []) << [field_options[:name], field]
      else
        ungrouped << [field_options[:name], field]
      end
    end
    # Remove empty groups
    grouped.delete_if {|k, v| v.empty?}
    # Don't group dates if there's only one (eg. time entries filters)
    if grouped[:label_date].try(:size) == 1
      ungrouped << grouped.delete(:label_date).first
    end
    s = options_for_select([[]] + ungrouped)
    if grouped.present?
      localized_grouped = grouped.map {|k, v| [k.is_a?(Symbol) ? l(k) : k.to_s, v]}
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

  def group_by_column_select_tag(query)
    options = [[]] + query.groupable_columns.collect {|c| [c.caption, c.name.to_s]}
    select_tag('group_by', options_for_select(options, @query.group_by))
  end

  def available_block_columns_tags(query)
    tags = ''.html_safe
    query.available_block_columns.each do |column|
      tags <<
        content_tag(
          'label',
          check_box_tag(
            'c[]', column.name.to_s,
            query.has_column?(column), :id => nil
          ) + " #{column.caption}", :class => 'inline'
        )
    end
    tags
  end

  def available_totalable_columns_tags(query, options={})
    tag_name = (options[:name] || 't') + '[]'
    tags = ''.html_safe
    query.available_totalable_columns.each do |column|
      tags <<
        content_tag(
          'label',
          check_box_tag(
            tag_name, column.name.to_s,
            query.totalable_columns.include?(column), :id => nil
          ) + " #{column.caption}", :class => 'inline'
        )
    end
    tags << hidden_field_tag(tag_name, '')
    tags
  end

  def query_available_inline_columns_options(query)
    (query.available_inline_columns - query.columns).
      reject(&:frozen?).collect {|column| [column.caption, column.name]}
  end

  def query_selected_inline_columns_options(query)
    (query.inline_columns & query.available_inline_columns).
      reject(&:frozen?).collect {|column| [column.caption, column.name]}
  end

  def render_query_columns_selection(query, options={})
    tag_name = (options[:name] || 'c') + '[]'
    render :partial => 'queries/columns', :locals => {:query => query, :tag_name => tag_name}
  end

  def available_display_types_tags(query)
    tags = ''.html_safe
    query.available_display_types.each do |t|
      tags << radio_button_tag('display_type', t, @query.display_type == t, :id => "display_type_#{t}") +
        content_tag('label', l(:"label_display_type_#{t}"), :for => "display_type_#{t}", :class => "inline")
    end
    tags
  end

  def grouped_query_results(items, query, &)
    result_count_by_group = query.result_count_by_group
    previous_group, first = false, true
    totals_by_group = query.totalable_columns.inject({}) do |h, column|
      h[column] = query.total_by_group_for(column)
      h
    end
    items.each do |item|
      group_name = group_count = nil
      if query.grouped?
        group = query.group_by_column.group_value(item)
        if first || group != previous_group
          if group.blank? && group != false
            group_name = "(#{l(:label_blank_value)})"
          else
            group_name = format_object(group)
          end
          group_name ||= ""
          group_count = result_count_by_group ? result_count_by_group[group] : nil
          group_totals = totals_by_group.map {|column, t| total_tag(column, t[group] || 0)}.join(" ").html_safe
        end
      end
      yield item, group_name, group_count, group_totals
      previous_group, first = group, false
    end
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
    value =
      if [:hours, :spent_hours, :total_spent_hours, :estimated_hours, :total_estimated_hours, :estimated_remaining_hours].include? column.name
        format_hours(value)
      else
        format_object(value)
      end
    value = content_tag('span', value, :class => 'value')
    content_tag('span', label + " " + value, :class => "total-for-#{column.name.to_s.dasherize}")
  end

  def column_header(query, column, options={})
    if column.sortable?
      css, order = nil, column.default_order
      if column.name.to_s == query.sort_criteria.first_key
        if query.sort_criteria.first_asc?
          css = 'sort asc icon icon-sorted-desc'
          icon = 'angle-up'
          order = 'desc'
        else
          css = 'sort desc icon icon-sorted-asc'
          icon = 'angle-down'
          order = 'asc'
        end
      end
      param_key = options[:sort_param] || :sort
      sort_param = {param_key => query.sort_criteria.add(column.name, order).to_param}
      sort_param = {$1 => {$2 => sort_param.values.first}} while sort_param.keys.first.to_s =~ /^(.+)\[(.+)\]$/
      link_options = {
        :title => l(:label_sort_by, "\"#{column.caption}\""),
        :class => css
      }
      if options[:sort_link_options]
        link_options.merge! options[:sort_link_options]
      end
      content =
        link_to(
          sprite_icon(icon, column.caption),
          {:params => request.query_parameters.deep_merge(sort_param)},
          link_options
        )
    else
      content = column.caption
    end
    content_tag('th', content, :class => column.css_classes)
  end

  def column_content(column, item)
    value = column.value_object(item)
    content =
      if value.is_a?(Array)
        values = value.filter_map {|v| column_value(column, item, v)}
        safe_join(values, ', ')
      else
        column_value(column, item, value)
      end

    call_hook(:helper_queries_column_content,
              {:content => content, :column => column, :item => item})

    content
  end

  def column_value(column, item, value)
    content =
      case column.name
      when :id
        link_to value, issue_path(item)
      when :subject
        link_to value, issue_path(item)
      when :parent, :'issue.parent'
        value ? (value.visible? ? link_to_issue(value, :subject => false) : "##{value.id}") : ''
      when :description
        item.description? ? content_tag('div', textilizable(item, :description), :class => "wiki") : ''
      when :last_notes
        item.last_notes.present? ? content_tag('div', textilizable(item, :last_notes), :class => "wiki") : ''
      when :done_ratio
        progress_bar(value)
      when :relations
        content_tag(
          'span',
          value.to_s(item) {|other| link_to_issue(other, :subject => false, :tracker => false)}.html_safe,
          :class => value.css_classes_for(item))
      when :hours, :estimated_hours, :total_estimated_hours, :estimated_remaining_hours
        format_hours(value)
      when :spent_hours
        link_to_if(value > 0, format_hours(value), project_time_entries_path(item.project, :issue_id => "#{item.id}"))
      when :total_spent_hours
        link_to_if(value > 0, format_hours(value), project_time_entries_path(item.project, :issue_id => "~#{item.id}"))
      when :attachments
        value.to_a.map {|a| format_object(a)}.join(" ").html_safe
      when :watcher_users
        content_tag('ul', value.to_a.map {|user| content_tag('li', format_object(user))}.join.html_safe)
      else
        format_object(value)
      end

    call_hook(:helper_queries_column_value,
              {:content => content, :column => column, :item => item, :value => value})

    content
  end

  def csv_content(column, item)
    value = column.value_object(item)
    if value.is_a?(Array)
      value.filter_map {|v| csv_value(column, item, v)}.join(', ')
    else
      csv_value(column, item, value)
    end
  end

  def csv_value(column, object, value)
    case column.name
    when :attachments
      value.to_a.map {|a| a.filename}.join("\n")
    when :watcher_users
      value.to_a.join("\n")
    else
      format_object(value, html: false) do |value|
        case value.class.name
        when 'Float', 'Rational'
          sprintf("%.2f", value).gsub('.', l(:general_csv_decimal_separator))
        when 'IssueRelation'
          value.to_s(object)
        when 'Issue'
          if object.is_a?(TimeEntry)
            value.visible? ? "#{value.tracker} ##{value.id}: #{value.subject}" : "##{value.id}"
          else
            value.id
          end
        else
          value
        end
      end
    end
  end

  def query_to_csv(items, query, options={})
    columns = query.columns

    Redmine::Export::CSV.generate(encoding: params[:encoding], field_separator: params[:field_separator]) do |csv|
      # csv header fields
      csv << columns.map {|c| c.caption.to_s}
      # csv lines
      items.each do |item|
        csv << columns.map {|c| csv_content(c, item)}
      end
    end
  end

  def filename_for_export(query, default_name)
    query_name = params[:query_name].presence || query.name
    query_name = default_name if query_name == '_' || query_name.blank?

    # Convert file names using the same rules as Wiki titles
    filename_for_content_disposition(Wiki.titleize(query_name).downcase)
  end

  # Retrieve query from session or build a new query
  def retrieve_query(klass=IssueQuery, use_session=true, options={})
    session_key = klass.name.underscore.to_sym

    if params[:query_id].present?
      scope = klass.where(:project_id => nil)
      scope = scope.or(klass.where(:project_id => @project)) if @project
      @query = scope.find(params[:query_id])
      raise ::Unauthorized unless @query.visible?

      @query.project = @project
      session[session_key] = {:id => @query.id, :project_id => @query.project_id} if use_session
    elsif api_request? || params[:set_filter] || !use_session ||
            session[session_key].nil? ||
            session[session_key][:project_id] != (@project ? @project.id : nil)
      # Give it a name, required to be valid
      @query = klass.new(:name => "_", :project => @project)
      @query.build_from_params(params, options[:defaults])
      if use_session
        session[session_key] = {
          :project_id => @query.project_id,
          :filters => @query.filters,
          :group_by => @query.group_by,
          :column_names => @query.column_names,
          :totalable_names => @query.totalable_names,
          :sort => @query.sort_criteria.to_a
        }
      end
    else
      # retrieve from session
      @query = nil
      @query = klass.find_by_id(session[session_key][:id]) if session[session_key][:id]
      @query ||=
        klass.new(
          :name => "_",
          :filters => session[session_key][:filters],
          :group_by => session[session_key][:group_by],
          :column_names => session[session_key][:column_names],
          :totalable_names => session[session_key][:totalable_names],
          :sort_criteria => session[session_key][:sort]
        )
      @query.project = @project
    end
    if params[:sort].present?
      @query.sort_criteria = params[:sort]
      if use_session
        session[session_key] ||= {}
        session[session_key][:sort] = @query.sort_criteria.to_a
      end
    end
    @query
  end

  def retrieve_query_from_session(klass=IssueQuery)
    session_key = klass.name.underscore.to_sym
    session_data = session[session_key]

    if session_data
      if session_data[:id]
        @query = IssueQuery.find_by_id(session_data[:id])
        return unless @query
      else
        @query =
          IssueQuery.new(
            :name => "_",
            :filters => session_data[:filters],
            :group_by => session_data[:group_by],
            :column_names => session_data[:column_names],
            :totalable_names => session_data[:totalable_names],
            :sort_criteria => session[session_key][:sort]
          )
      end
      if session_data.has_key?(:project_id)
        @query.project_id = session_data[:project_id]
      else
        @query.project = @project
      end
      @query
    else
      @query = klass.default project: @project
    end
  end

  # Returns the query definition as hidden field tags
  def query_as_hidden_field_tags(query)
    tags = hidden_field_tag("set_filter", "1", :id => nil)

    if query.filters.present?
      query.filters.each do |field, filter|
        tags << hidden_field_tag("f[]", field, :id => nil)
        tags << hidden_field_tag("op[#{field}]", filter[:operator], :id => nil)
        filter[:values].each do |value|
          tags << hidden_field_tag("v[#{field}][]", value, :id => nil)
        end
      end
    else
      tags << hidden_field_tag("f[]", "", :id => nil)
    end
    query.columns.each do |column|
      tags << hidden_field_tag("c[]", column.name, :id => nil)
    end
    if query.totalable_names.present?
      query.totalable_names.each do |name|
        tags << hidden_field_tag("t[]", name, :id => nil)
      end
    end
    if query.group_by.present?
      tags << hidden_field_tag("group_by", query.group_by, :id => nil)
    end
    if query.sort_criteria.present?
      tags << hidden_field_tag("sort", query.sort_criteria.to_param, :id => nil)
    end

    tags
  end

  def query_hidden_sort_tag(query)
    hidden_field_tag("sort", query.sort_criteria.to_param, :id => nil)
  end

  # Returns the queries that are rendered in the sidebar
  def sidebar_queries(klass, project)
    klass.visible.global_or_on_project(@project).sorted.to_a
  end

  # Renders a group of queries
  def query_links(title, queries)
    return '' if queries.empty?

    # links to #index on issues/show
    url_params =
      if controller_name == 'issues'
        {:controller => 'issues', :action => 'index', :project_id => @project}
      else
        {}
      end
    default_query_by_class = {}
    content_tag('h3', title) + "\n" +
      content_tag(
        'ul',
        queries.collect do |query|
          css = +'query'
          clear_link = +''
          clear_link_param = {:set_filter => 1, :sort => '', :project_id => @project}

          default_query =
            default_query_by_class[query.class] ||= query.class.default(project: @project)
          if query == default_query
            css << ' default'
            clear_link_param[:without_default] = 1
          end

          if query == @query
            css << ' selected'
            clear_link += link_to_clear_query(clear_link_param)
          end
          content_tag('li',
                      link_to(query.name,
                              url_params.merge(:query_id => query),
                              :class => css,
                              :title => query.description,
                              :data => { :disable_with => CGI.escapeHTML(query.name) }) +
                        clear_link.html_safe)
        end.join("\n").html_safe,
        :class => 'queries'
      ) + "\n"
  end

  def link_to_clear_query(params = {:set_filter => 1, :sort => '', :project_id => @project})
    link_to(
      sprite_icon('clear-query', l(:button_clear)),
      params,
      :class => 'icon-only icon-clear-query',
      :title => l(:button_clear)
    )
  end

  # Renders the list of queries for the sidebar
  def render_sidebar_queries(klass, project)
    queries = sidebar_queries(klass, project)

    out = ''.html_safe
    out << query_links(l(:label_my_queries), queries.select(&:is_private?))
    out << query_links(l(:label_query_plural), queries.reject(&:is_private?))
    out
  end
end
