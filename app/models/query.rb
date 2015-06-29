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

class QueryColumn
  attr_accessor :name, :sortable, :groupable, :default_order
  include Redmine::I18n

  def initialize(name, options={})
    self.name = name
    self.sortable = options[:sortable]
    self.groupable = options[:groupable] || false
    if groupable == true
      self.groupable = name.to_s
    end
    self.default_order = options[:default_order]
    @inline = options.key?(:inline) ? options[:inline] : true
    @caption_key = options[:caption] || "field_#{name}".to_sym
    @frozen = options[:frozen]
  end

  def caption
    case @caption_key
    when Symbol
      l(@caption_key)
    when Proc
      @caption_key.call
    else
      @caption_key
    end
  end

  # Returns true if the column is sortable, otherwise false
  def sortable?
    !@sortable.nil?
  end

  def sortable
    @sortable.is_a?(Proc) ? @sortable.call : @sortable
  end

  def inline?
    @inline
  end

  def frozen?
    @frozen
  end

  def value(object)
    object.send name
  end

  def value_object(object)
    object.send name
  end

  def css_classes
    name
  end
end

class QueryCustomFieldColumn < QueryColumn

  def initialize(custom_field)
    self.name = "cf_#{custom_field.id}".to_sym
    self.sortable = custom_field.order_statement || false
    self.groupable = custom_field.group_statement || false
    @inline = true
    @cf = custom_field
  end

  def caption
    @cf.name
  end

  def custom_field
    @cf
  end

  def value_object(object)
    if custom_field.visible_by?(object.project, User.current)
      cv = object.custom_values.select {|v| v.custom_field_id == @cf.id}
      cv.size > 1 ? cv.sort {|a,b| a.value.to_s <=> b.value.to_s} : cv.first
    else
      nil
    end
  end

  def value(object)
    raw = value_object(object)
    if raw.is_a?(Array)
      raw.map {|r| @cf.cast_value(r.value)}
    elsif raw
      @cf.cast_value(raw.value)
    else
      nil
    end
  end

  def css_classes
    @css_classes ||= "#{name} #{@cf.field_format}"
  end
end

class QueryAssociationCustomFieldColumn < QueryCustomFieldColumn

  def initialize(association, custom_field)
    super(custom_field)
    self.name = "#{association}.cf_#{custom_field.id}".to_sym
    # TODO: support sorting/grouping by association custom field
    self.sortable = false
    self.groupable = false
    @association = association
  end

  def value_object(object)
    if assoc = object.send(@association)
      super(assoc)
    end
  end

  def css_classes
    @css_classes ||= "#{@association}_cf_#{@cf.id} #{@cf.field_format}"
  end
end

class Query < ActiveRecord::Base
  class StatementInvalid < ::ActiveRecord::StatementInvalid
  end

  VISIBILITY_PRIVATE = 0
  VISIBILITY_ROLES   = 1
  VISIBILITY_PUBLIC  = 2

  belongs_to :project
  belongs_to :user
  has_and_belongs_to_many :roles, :join_table => "#{table_name_prefix}queries_roles#{table_name_suffix}", :foreign_key => "query_id"
  serialize :filters
  serialize :column_names
  serialize :sort_criteria, Array
  serialize :options, Hash

  attr_protected :project_id, :user_id

  validates_presence_of :name
  validates_length_of :name, :maximum => 255
  validates :visibility, :inclusion => { :in => [VISIBILITY_PUBLIC, VISIBILITY_ROLES, VISIBILITY_PRIVATE] }
  validate :validate_query_filters
  validate do |query|
    errors.add(:base, l(:label_role_plural) + ' ' + l('activerecord.errors.messages.blank')) if query.visibility == VISIBILITY_ROLES && roles.blank?
  end

  after_save do |query|
    if query.visibility_changed? && query.visibility != VISIBILITY_ROLES
      query.roles.clear
    end
  end

  class_attribute :operators
  self.operators = {
    "="   => :label_equals,
    "!"   => :label_not_equals,
    "o"   => :label_open_issues,
    "c"   => :label_closed_issues,
    "!*"  => :label_none,
    "*"   => :label_any,
    ">="  => :label_greater_or_equal,
    "<="  => :label_less_or_equal,
    "><"  => :label_between,
    "<t+" => :label_in_less_than,
    ">t+" => :label_in_more_than,
    "><t+"=> :label_in_the_next_days,
    "t+"  => :label_in,
    "t"   => :label_today,
    "ld"  => :label_yesterday,
    "w"   => :label_this_week,
    "lw"  => :label_last_week,
    "l2w" => [:label_last_n_weeks, {:count => 2}],
    "m"   => :label_this_month,
    "lm"  => :label_last_month,
    "y"   => :label_this_year,
    ">t-" => :label_less_than_ago,
    "<t-" => :label_more_than_ago,
    "><t-"=> :label_in_the_past_days,
    "t-"  => :label_ago,
    "~"   => :label_contains,
    "!~"  => :label_not_contains,
    "=p"  => :label_any_issues_in_project,
    "=!p" => :label_any_issues_not_in_project,
    "!p"  => :label_no_issues_in_project
  }

  class_attribute :operators_by_filter_type
  self.operators_by_filter_type = {
    :list => [ "=", "!" ],
    :list_status => [ "o", "=", "!", "c", "*" ],
    :list_optional => [ "=", "!", "!*", "*" ],
    :list_subprojects => [ "*", "!*", "=" ],
    :date => [ "=", ">=", "<=", "><", "<t+", ">t+", "><t+", "t+", "t", "ld", "w", "lw", "l2w", "m", "lm", "y", ">t-", "<t-", "><t-", "t-", "!*", "*" ],
    :date_past => [ "=", ">=", "<=", "><", ">t-", "<t-", "><t-", "t-", "t", "ld", "w", "lw", "l2w", "m", "lm", "y", "!*", "*" ],
    :string => [ "=", "~", "!", "!~", "!*", "*" ],
    :text => [  "~", "!~", "!*", "*" ],
    :integer => [ "=", ">=", "<=", "><", "!*", "*" ],
    :float => [ "=", ">=", "<=", "><", "!*", "*" ],
    :relation => ["=", "=p", "=!p", "!p", "!*", "*"],
    :tree => ["=", "~", "!*", "*"]
  }

  class_attribute :available_columns
  self.available_columns = []

  class_attribute :queried_class

  def queried_table_name
    @queried_table_name ||= self.class.queried_class.table_name
  end

  def initialize(attributes=nil, *args)
    super attributes
    @is_for_all = project.nil?
  end

  # Builds the query from the given params
  def build_from_params(params)
    if params[:fields] || params[:f]
      self.filters = {}
      add_filters(params[:fields] || params[:f], params[:operators] || params[:op], params[:values] || params[:v])
    else
      available_filters.keys.each do |field|
        add_short_filter(field, params[field]) if params[field]
      end
    end
    self.group_by = params[:group_by] || (params[:query] && params[:query][:group_by])
    self.column_names = params[:c] || (params[:query] && params[:query][:column_names])
    self
  end

  # Builds a new query from the given params and attributes
  def self.build_from_params(params, attributes={})
    new(attributes).build_from_params(params)
  end

  def validate_query_filters
    filters.each_key do |field|
      if values_for(field)
        case type_for(field)
        when :integer
          add_filter_error(field, :invalid) if values_for(field).detect {|v| v.present? && !v.match(/^[+-]?\d+$/) }
        when :float
          add_filter_error(field, :invalid) if values_for(field).detect {|v| v.present? && !v.match(/^[+-]?\d+(\.\d*)?$/) }
        when :date, :date_past
          case operator_for(field)
          when "=", ">=", "<=", "><"
            add_filter_error(field, :invalid) if values_for(field).detect {|v|
              v.present? && (!v.match(/\A\d{4}-\d{2}-\d{2}(T\d{2}((:)?\d{2}){0,2}(Z|\d{2}:?\d{2})?)?\z/) || parse_date(v).nil?)
            }
          when ">t-", "<t-", "t-", ">t+", "<t+", "t+", "><t+", "><t-"
            add_filter_error(field, :invalid) if values_for(field).detect {|v| v.present? && !v.match(/^\d+$/) }
          end
        end
      end

      add_filter_error(field, :blank) unless
          # filter requires one or more values
          (values_for(field) and !values_for(field).first.blank?) or
          # filter doesn't require any value
          ["o", "c", "!*", "*", "t", "ld", "w", "lw", "l2w", "m", "lm", "y"].include? operator_for(field)
    end if filters
  end

  def add_filter_error(field, message)
    m = label_for(field) + " " + l(message, :scope => 'activerecord.errors.messages')
    errors.add(:base, m)
  end

  def editable_by?(user)
    return false unless user
    # Admin can edit them all and regular users can edit their private queries
    return true if user.admin? || (is_private? && self.user_id == user.id)
    # Members can not edit public queries that are for all project (only admin is allowed to)
    is_public? && !@is_for_all && user.allowed_to?(:manage_public_queries, project)
  end

  def trackers
    @trackers ||= project.nil? ? Tracker.sorted.to_a : project.rolled_up_trackers
  end

  # Returns a hash of localized labels for all filter operators
  def self.operators_labels
    operators.inject({}) {|h, operator| h[operator.first] = l(*operator.last); h}
  end

  # Returns a representation of the available filters for JSON serialization
  def available_filters_as_json
    json = {}
    available_filters.each do |field, options|
      json[field] = options.slice(:type, :name, :values).stringify_keys
    end
    json
  end

  def all_projects
    @all_projects ||= Project.visible.to_a
  end

  def all_projects_values
    return @all_projects_values if @all_projects_values

    values = []
    Project.project_tree(all_projects) do |p, level|
      prefix = (level > 0 ? ('--' * level + ' ') : '')
      values << ["#{prefix}#{p.name}", p.id.to_s]
    end
    @all_projects_values = values
  end

  # Adds available filters
  def initialize_available_filters
    # implemented by sub-classes
  end
  protected :initialize_available_filters

  # Adds an available filter
  def add_available_filter(field, options)
    @available_filters ||= ActiveSupport::OrderedHash.new
    @available_filters[field] = options
    @available_filters
  end

  # Removes an available filter
  def delete_available_filter(field)
    if @available_filters
      @available_filters.delete(field)
    end
  end

  # Return a hash of available filters
  def available_filters
    unless @available_filters
      initialize_available_filters
      @available_filters.each do |field, options|
        options[:name] ||= l(options[:label] || "field_#{field}".gsub(/_id$/, ''))
      end
    end
    @available_filters
  end

  def add_filter(field, operator, values=nil)
    # values must be an array
    return unless values.nil? || values.is_a?(Array)
    # check if field is defined as an available filter
    if available_filters.has_key? field
      filter_options = available_filters[field]
      filters[field] = {:operator => operator, :values => (values || [''])}
    end
  end

  def add_short_filter(field, expression)
    return unless expression && available_filters.has_key?(field)
    field_type = available_filters[field][:type]
    operators_by_filter_type[field_type].sort.reverse.detect do |operator|
      next unless expression =~ /^#{Regexp.escape(operator)}(.*)$/
      values = $1
      add_filter field, operator, values.present? ? values.split('|') : ['']
    end || add_filter(field, '=', expression.split('|'))
  end

  # Add multiple filters using +add_filter+
  def add_filters(fields, operators, values)
    if fields.is_a?(Array) && operators.is_a?(Hash) && (values.nil? || values.is_a?(Hash))
      fields.each do |field|
        add_filter(field, operators[field], values && values[field])
      end
    end
  end

  def has_filter?(field)
    filters and filters[field]
  end

  def type_for(field)
    available_filters[field][:type] if available_filters.has_key?(field)
  end

  def operator_for(field)
    has_filter?(field) ? filters[field][:operator] : nil
  end

  def values_for(field)
    has_filter?(field) ? filters[field][:values] : nil
  end

  def value_for(field, index=0)
    (values_for(field) || [])[index]
  end

  def label_for(field)
    label = available_filters[field][:name] if available_filters.has_key?(field)
    label ||= l("field_#{field.to_s.gsub(/_id$/, '')}", :default => field)
  end

  def self.add_available_column(column)
    self.available_columns << (column) if column.is_a?(QueryColumn)
  end

  # Returns an array of columns that can be used to group the results
  def groupable_columns
    available_columns.select {|c| c.groupable}
  end

  # Returns a Hash of columns and the key for sorting
  def sortable_columns
    available_columns.inject({}) {|h, column|
      h[column.name.to_s] = column.sortable
      h
    }
  end

  def columns
    # preserve the column_names order
    cols = (has_default_columns? ? default_columns_names : column_names).collect do |name|
       available_columns.find { |col| col.name == name }
    end.compact
    available_columns.select(&:frozen?) | cols
  end

  def inline_columns
    columns.select(&:inline?)
  end

  def block_columns
    columns.reject(&:inline?)
  end

  def available_inline_columns
    available_columns.select(&:inline?)
  end

  def available_block_columns
    available_columns.reject(&:inline?)
  end

  def default_columns_names
    []
  end

  def column_names=(names)
    if names
      names = names.select {|n| n.is_a?(Symbol) || !n.blank? }
      names = names.collect {|n| n.is_a?(Symbol) ? n : n.to_sym }
      # Set column_names to nil if default columns
      if names == default_columns_names
        names = nil
      end
    end
    write_attribute(:column_names, names)
  end

  def has_column?(column)
    column_names && column_names.include?(column.is_a?(QueryColumn) ? column.name : column)
  end

  def has_custom_field_column?
    columns.any? {|column| column.is_a? QueryCustomFieldColumn}
  end

  def has_default_columns?
    column_names.nil? || column_names.empty?
  end

  def sort_criteria=(arg)
    c = []
    if arg.is_a?(Hash)
      arg = arg.keys.sort.collect {|k| arg[k]}
    end
    if arg
      c = arg.select {|k,o| !k.to_s.blank?}.slice(0,3).collect {|k,o| [k.to_s, (o == 'desc' || o == false) ? 'desc' : 'asc']}
    end
    write_attribute(:sort_criteria, c)
  end

  def sort_criteria
    read_attribute(:sort_criteria) || []
  end

  def sort_criteria_key(arg)
    sort_criteria && sort_criteria[arg] && sort_criteria[arg].first
  end

  def sort_criteria_order(arg)
    sort_criteria && sort_criteria[arg] && sort_criteria[arg].last
  end

  def sort_criteria_order_for(key)
    sort_criteria.detect {|k, order| key.to_s == k}.try(:last)
  end

  # Returns the SQL sort order that should be prepended for grouping
  def group_by_sort_order
    if grouped? && (column = group_by_column)
      order = (sort_criteria_order_for(column.name) || column.default_order).try(:upcase)
      column.sortable.is_a?(Array) ?
        column.sortable.collect {|s| "#{s} #{order}"}.join(',') :
        "#{column.sortable} #{order}"
    end
  end

  # Returns true if the query is a grouped query
  def grouped?
    !group_by_column.nil?
  end

  def group_by_column
    groupable_columns.detect {|c| c.groupable && c.name.to_s == group_by}
  end

  def group_by_statement
    group_by_column.try(:groupable)
  end

  def project_statement
    project_clauses = []
    if project && !project.descendants.active.empty?
      ids = [project.id]
      if has_filter?("subproject_id")
        case operator_for("subproject_id")
        when '='
          # include the selected subprojects
          ids += values_for("subproject_id").each(&:to_i)
        when '!*'
          # main project only
        else
          # all subprojects
          ids += project.descendants.collect(&:id)
        end
      elsif Setting.display_subprojects_issues?
        ids += project.descendants.collect(&:id)
      end
      project_clauses << "#{Project.table_name}.id IN (%s)" % ids.join(',')
    elsif project
      project_clauses << "#{Project.table_name}.id = %d" % project.id
    end
    project_clauses.any? ? project_clauses.join(' AND ') : nil
  end

  def statement
    # filters clauses
    filters_clauses = []
    filters.each_key do |field|
      next if field == "subproject_id"
      v = values_for(field).clone
      next unless v and !v.empty?
      operator = operator_for(field)

      # "me" value substitution
      if %w(assigned_to_id author_id user_id watcher_id).include?(field)
        if v.delete("me")
          if User.current.logged?
            v.push(User.current.id.to_s)
            v += User.current.group_ids.map(&:to_s) if field == 'assigned_to_id'
          else
            v.push("0")
          end
        end
      end

      if field == 'project_id'
        if v.delete('mine')
          v += User.current.memberships.map(&:project_id).map(&:to_s)
        end
      end

      if field =~ /cf_(\d+)$/
        # custom field
        filters_clauses << sql_for_custom_field(field, operator, v, $1)
      elsif respond_to?("sql_for_#{field}_field")
        # specific statement
        filters_clauses << send("sql_for_#{field}_field", field, operator, v)
      else
        # regular field
        filters_clauses << '(' + sql_for_field(field, operator, v, queried_table_name, field) + ')'
      end
    end if filters and valid?

    if (c = group_by_column) && c.is_a?(QueryCustomFieldColumn)
      # Excludes results for which the grouped custom field is not visible
      filters_clauses << c.custom_field.visibility_by_project_condition
    end

    filters_clauses << project_statement
    filters_clauses.reject!(&:blank?)

    filters_clauses.any? ? filters_clauses.join(' AND ') : nil
  end

  private

  def sql_for_custom_field(field, operator, value, custom_field_id)
    db_table = CustomValue.table_name
    db_field = 'value'
    filter = @available_filters[field]
    return nil unless filter
    if filter[:field].format.target_class && filter[:field].format.target_class <= User
      if value.delete('me')
        value.push User.current.id.to_s
      end
    end
    not_in = nil
    if operator == '!'
      # Makes ! operator work for custom fields with multiple values
      operator = '='
      not_in = 'NOT'
    end
    customized_key = "id"
    customized_class = queried_class
    if field =~ /^(.+)\.cf_/
      assoc = $1
      customized_key = "#{assoc}_id"
      customized_class = queried_class.reflect_on_association(assoc.to_sym).klass.base_class rescue nil
      raise "Unknown #{queried_class.name} association #{assoc}" unless customized_class
    end
    where = sql_for_field(field, operator, value, db_table, db_field, true)
    if operator =~ /[<>]/
      where = "(#{where}) AND #{db_table}.#{db_field} <> ''"
    end
    "#{queried_table_name}.#{customized_key} #{not_in} IN (" +
      "SELECT #{customized_class.table_name}.id FROM #{customized_class.table_name}" +
      " LEFT OUTER JOIN #{db_table} ON #{db_table}.customized_type='#{customized_class}' AND #{db_table}.customized_id=#{customized_class.table_name}.id AND #{db_table}.custom_field_id=#{custom_field_id}" +
      " WHERE (#{where}) AND (#{filter[:field].visibility_by_project_condition}))"
  end

  # Helper method to generate the WHERE sql for a +field+, +operator+ and a +value+
  def sql_for_field(field, operator, value, db_table, db_field, is_custom_filter=false)
    sql = ''
    case operator
    when "="
      if value.any?
        case type_for(field)
        when :date, :date_past
          sql = date_clause(db_table, db_field, parse_date(value.first), parse_date(value.first), is_custom_filter)
        when :integer
          if is_custom_filter
            sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) = #{value.first.to_i})"
          else
            sql = "#{db_table}.#{db_field} = #{value.first.to_i}"
          end
        when :float
          if is_custom_filter
            sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) BETWEEN #{value.first.to_f - 1e-5} AND #{value.first.to_f + 1e-5})"
          else
            sql = "#{db_table}.#{db_field} BETWEEN #{value.first.to_f - 1e-5} AND #{value.first.to_f + 1e-5}"
          end
        else
          sql = "#{db_table}.#{db_field} IN (" + value.collect{|val| "'#{self.class.connection.quote_string(val)}'"}.join(",") + ")"
        end
      else
        # IN an empty set
        sql = "1=0"
      end
    when "!"
      if value.any?
        sql = "(#{db_table}.#{db_field} IS NULL OR #{db_table}.#{db_field} NOT IN (" + value.collect{|val| "'#{self.class.connection.quote_string(val)}'"}.join(",") + "))"
      else
        # NOT IN an empty set
        sql = "1=1"
      end
    when "!*"
      sql = "#{db_table}.#{db_field} IS NULL"
      sql << " OR #{db_table}.#{db_field} = ''" if is_custom_filter
    when "*"
      sql = "#{db_table}.#{db_field} IS NOT NULL"
      sql << " AND #{db_table}.#{db_field} <> ''" if is_custom_filter
    when ">="
      if [:date, :date_past].include?(type_for(field))
        sql = date_clause(db_table, db_field, parse_date(value.first), nil, is_custom_filter)
      else
        if is_custom_filter
          sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) >= #{value.first.to_f})"
        else
          sql = "#{db_table}.#{db_field} >= #{value.first.to_f}"
        end
      end
    when "<="
      if [:date, :date_past].include?(type_for(field))
        sql = date_clause(db_table, db_field, nil, parse_date(value.first), is_custom_filter)
      else
        if is_custom_filter
          sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) <= #{value.first.to_f})"
        else
          sql = "#{db_table}.#{db_field} <= #{value.first.to_f}"
        end
      end
    when "><"
      if [:date, :date_past].include?(type_for(field))
        sql = date_clause(db_table, db_field, parse_date(value[0]), parse_date(value[1]), is_custom_filter)
      else
        if is_custom_filter
          sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) BETWEEN #{value[0].to_f} AND #{value[1].to_f})"
        else
          sql = "#{db_table}.#{db_field} BETWEEN #{value[0].to_f} AND #{value[1].to_f}"
        end
      end
    when "o"
      sql = "#{queried_table_name}.status_id IN (SELECT id FROM #{IssueStatus.table_name} WHERE is_closed=#{self.class.connection.quoted_false})" if field == "status_id"
    when "c"
      sql = "#{queried_table_name}.status_id IN (SELECT id FROM #{IssueStatus.table_name} WHERE is_closed=#{self.class.connection.quoted_true})" if field == "status_id"
    when "><t-"
      # between today - n days and today
      sql = relative_date_clause(db_table, db_field, - value.first.to_i, 0, is_custom_filter)
    when ">t-"
      # >= today - n days
      sql = relative_date_clause(db_table, db_field, - value.first.to_i, nil, is_custom_filter)
    when "<t-"
      # <= today - n days
      sql = relative_date_clause(db_table, db_field, nil, - value.first.to_i, is_custom_filter)
    when "t-"
      # = n days in past
      sql = relative_date_clause(db_table, db_field, - value.first.to_i, - value.first.to_i, is_custom_filter)
    when "><t+"
      # between today and today + n days
      sql = relative_date_clause(db_table, db_field, 0, value.first.to_i, is_custom_filter)
    when ">t+"
      # >= today + n days
      sql = relative_date_clause(db_table, db_field, value.first.to_i, nil, is_custom_filter)
    when "<t+"
      # <= today + n days
      sql = relative_date_clause(db_table, db_field, nil, value.first.to_i, is_custom_filter)
    when "t+"
      # = today + n days
      sql = relative_date_clause(db_table, db_field, value.first.to_i, value.first.to_i, is_custom_filter)
    when "t"
      # = today
      sql = relative_date_clause(db_table, db_field, 0, 0, is_custom_filter)
    when "ld"
      # = yesterday
      sql = relative_date_clause(db_table, db_field, -1, -1, is_custom_filter)
    when "w"
      # = this week
      first_day_of_week = l(:general_first_day_of_week).to_i
      day_of_week = Date.today.cwday
      days_ago = (day_of_week >= first_day_of_week ? day_of_week - first_day_of_week : day_of_week + 7 - first_day_of_week)
      sql = relative_date_clause(db_table, db_field, - days_ago, - days_ago + 6, is_custom_filter)
    when "lw"
      # = last week
      first_day_of_week = l(:general_first_day_of_week).to_i
      day_of_week = Date.today.cwday
      days_ago = (day_of_week >= first_day_of_week ? day_of_week - first_day_of_week : day_of_week + 7 - first_day_of_week)
      sql = relative_date_clause(db_table, db_field, - days_ago - 7, - days_ago - 1, is_custom_filter)
    when "l2w"
      # = last 2 weeks
      first_day_of_week = l(:general_first_day_of_week).to_i
      day_of_week = Date.today.cwday
      days_ago = (day_of_week >= first_day_of_week ? day_of_week - first_day_of_week : day_of_week + 7 - first_day_of_week)
      sql = relative_date_clause(db_table, db_field, - days_ago - 14, - days_ago - 1, is_custom_filter)
    when "m"
      # = this month
      date = Date.today
      sql = date_clause(db_table, db_field, date.beginning_of_month, date.end_of_month, is_custom_filter)
    when "lm"
      # = last month
      date = Date.today.prev_month
      sql = date_clause(db_table, db_field, date.beginning_of_month, date.end_of_month, is_custom_filter)
    when "y"
      # = this year
      date = Date.today
      sql = date_clause(db_table, db_field, date.beginning_of_year, date.end_of_year, is_custom_filter)
    when "~"
      sql = "LOWER(#{db_table}.#{db_field}) LIKE '%#{self.class.connection.quote_string(value.first.to_s.downcase)}%'"
    when "!~"
      sql = "LOWER(#{db_table}.#{db_field}) NOT LIKE '%#{self.class.connection.quote_string(value.first.to_s.downcase)}%'"
    else
      raise "Unknown query operator #{operator}"
    end

    return sql
  end

  # Adds a filter for the given custom field
  def add_custom_field_filter(field, assoc=nil)
    options = field.format.query_filter_options(field, self)
    if field.format.target_class && field.format.target_class <= User
      if options[:values].is_a?(Array) && User.current.logged?
        options[:values].unshift ["<< #{l(:label_me)} >>", "me"]
      end
    end

    filter_id = "cf_#{field.id}"
    filter_name = field.name
    if assoc.present?
      filter_id = "#{assoc}.#{filter_id}"
      filter_name = l("label_attribute_of_#{assoc}", :name => filter_name)
    end
    add_available_filter filter_id, options.merge({
      :name => filter_name,
      :field => field
    })
  end

  # Adds filters for the given custom fields scope
  def add_custom_fields_filters(scope, assoc=nil)
    scope.visible.where(:is_filter => true).sorted.each do |field|
      add_custom_field_filter(field, assoc)
    end
  end

  # Adds filters for the given associations custom fields
  def add_associations_custom_fields_filters(*associations)
    fields_by_class = CustomField.visible.where(:is_filter => true).group_by(&:class)
    associations.each do |assoc|
      association_klass = queried_class.reflect_on_association(assoc).klass
      fields_by_class.each do |field_class, fields|
        if field_class.customized_class <= association_klass
          fields.sort.each do |field|
            add_custom_field_filter(field, assoc)
          end
        end
      end
    end
  end

  def quoted_time(time, is_custom_filter)
    if is_custom_filter
      # Custom field values are stored as strings in the DB
      # using this format that does not depend on DB date representation
      time.strftime("%Y-%m-%d %H:%M:%S")
    else
      self.class.connection.quoted_date(time)
    end
  end

  # Returns a SQL clause for a date or datetime field.
  def date_clause(table, field, from, to, is_custom_filter)
    s = []
    if from
      if from.is_a?(Date)
        from = Time.local(from.year, from.month, from.day).yesterday.end_of_day
      else
        from = from - 1 # second
      end
      if self.class.default_timezone == :utc
        from = from.utc
      end
      s << ("#{table}.#{field} > '%s'" % [quoted_time(from, is_custom_filter)])
    end
    if to
      if to.is_a?(Date)
        to = Time.local(to.year, to.month, to.day).end_of_day
      end
      if self.class.default_timezone == :utc
        to = to.utc
      end
      s << ("#{table}.#{field} <= '%s'" % [quoted_time(to, is_custom_filter)])
    end
    s.join(' AND ')
  end

  # Returns a SQL clause for a date or datetime field using relative dates.
  def relative_date_clause(table, field, days_from, days_to, is_custom_filter)
    date_clause(table, field, (days_from ? Date.today + days_from : nil), (days_to ? Date.today + days_to : nil), is_custom_filter)
  end

  # Returns a Date or Time from the given filter value
  def parse_date(arg)
    if arg.to_s =~ /\A\d{4}-\d{2}-\d{2}T/
      Time.parse(arg) rescue nil
    else
      Date.parse(arg) rescue nil
    end
  end

  # Additional joins required for the given sort options
  def joins_for_order_statement(order_options)
    joins = []

    if order_options
      if order_options.include?('authors')
        joins << "LEFT OUTER JOIN #{User.table_name} authors ON authors.id = #{queried_table_name}.author_id"
      end
      order_options.scan(/cf_\d+/).uniq.each do |name|
        column = available_columns.detect {|c| c.name.to_s == name}
        join = column && column.custom_field.join_for_order_statement
        if join
          joins << join
        end
      end
    end

    joins.any? ? joins.join(' ') : nil
  end
end
