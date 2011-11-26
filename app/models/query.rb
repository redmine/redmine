# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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
    @caption_key = options[:caption] || "field_#{name}"
  end

  def caption
    l(@caption_key)
  end

  # Returns true if the column is sortable, otherwise false
  def sortable?
    !@sortable.nil?
  end
  
  def sortable
    @sortable.is_a?(Proc) ? @sortable.call : @sortable
  end

  def value(issue)
    issue.send name
  end

  def css_classes
    name
  end
end

class QueryCustomFieldColumn < QueryColumn

  def initialize(custom_field)
    self.name = "cf_#{custom_field.id}".to_sym
    self.sortable = custom_field.order_statement || false
    if %w(list date bool int).include?(custom_field.field_format)
      self.groupable = custom_field.order_statement
    end
    self.groupable ||= false
    @cf = custom_field
  end

  def caption
    @cf.name
  end

  def custom_field
    @cf
  end

  def value(issue)
    cv = issue.custom_values.detect {|v| v.custom_field_id == @cf.id}
    cv && @cf.cast_value(cv.value)
  end

  def css_classes
    @css_classes ||= "#{name} #{@cf.field_format}"
  end
end

class Query < ActiveRecord::Base
  class StatementInvalid < ::ActiveRecord::StatementInvalid
  end

  belongs_to :project
  belongs_to :user
  serialize :filters
  serialize :column_names
  serialize :sort_criteria, Array

  attr_protected :project_id, :user_id

  validates_presence_of :name, :on => :save
  validates_length_of :name, :maximum => 255
  validate :validate_query_filters

  @@operators = { "="   => :label_equals,
                  "!"   => :label_not_equals,
                  "o"   => :label_open_issues,
                  "c"   => :label_closed_issues,
                  "!*"  => :label_none,
                  "*"   => :label_all,
                  ">="  => :label_greater_or_equal,
                  "<="  => :label_less_or_equal,
                  "><"  => :label_between,
                  "<t+" => :label_in_less_than,
                  ">t+" => :label_in_more_than,
                  "t+"  => :label_in,
                  "t"   => :label_today,
                  "w"   => :label_this_week,
                  ">t-" => :label_less_than_ago,
                  "<t-" => :label_more_than_ago,
                  "t-"  => :label_ago,
                  "~"   => :label_contains,
                  "!~"  => :label_not_contains }

  cattr_reader :operators

  @@operators_by_filter_type = { :list => [ "=", "!" ],
                                 :list_status => [ "o", "=", "!", "c", "*" ],
                                 :list_optional => [ "=", "!", "!*", "*" ],
                                 :list_subprojects => [ "*", "!*", "=" ],
                                 :date => [ "=", ">=", "<=", "><", "<t+", ">t+", "t+", "t", "w", ">t-", "<t-", "t-", "!*", "*" ],
                                 :date_past => [ "=", ">=", "<=", "><", ">t-", "<t-", "t-", "t", "w", "!*", "*" ],
                                 :string => [ "=", "~", "!", "!~" ],
                                 :text => [  "~", "!~" ],
                                 :integer => [ "=", ">=", "<=", "><", "!*", "*" ],
                                 :float => [ "=", ">=", "<=", "><", "!*", "*" ] }

  cattr_reader :operators_by_filter_type

  @@available_columns = [
    QueryColumn.new(:project, :sortable => "#{Project.table_name}.name", :groupable => true),
    QueryColumn.new(:tracker, :sortable => "#{Tracker.table_name}.position", :groupable => true),
    QueryColumn.new(:parent, :sortable => ["#{Issue.table_name}.root_id", "#{Issue.table_name}.lft ASC"], :default_order => 'desc', :caption => :field_parent_issue),
    QueryColumn.new(:status, :sortable => "#{IssueStatus.table_name}.position", :groupable => true),
    QueryColumn.new(:priority, :sortable => "#{IssuePriority.table_name}.position", :default_order => 'desc', :groupable => true),
    QueryColumn.new(:subject, :sortable => "#{Issue.table_name}.subject"),
    QueryColumn.new(:author, :sortable => lambda {User.fields_for_order_statement("authors")}, :groupable => true),
    QueryColumn.new(:assigned_to, :sortable => lambda {User.fields_for_order_statement}, :groupable => true),
    QueryColumn.new(:updated_on, :sortable => "#{Issue.table_name}.updated_on", :default_order => 'desc'),
    QueryColumn.new(:category, :sortable => "#{IssueCategory.table_name}.name", :groupable => true),
    QueryColumn.new(:fixed_version, :sortable => ["#{Version.table_name}.effective_date", "#{Version.table_name}.name"], :default_order => 'desc', :groupable => true),
    QueryColumn.new(:start_date, :sortable => "#{Issue.table_name}.start_date"),
    QueryColumn.new(:due_date, :sortable => "#{Issue.table_name}.due_date"),
    QueryColumn.new(:estimated_hours, :sortable => "#{Issue.table_name}.estimated_hours"),
    QueryColumn.new(:done_ratio, :sortable => "#{Issue.table_name}.done_ratio", :groupable => true),
    QueryColumn.new(:created_on, :sortable => "#{Issue.table_name}.created_on", :default_order => 'desc'),
  ]
  cattr_reader :available_columns

  named_scope :visible, lambda {|*args|
    user = args.shift || User.current
    base = Project.allowed_to_condition(user, :view_issues, *args)
    user_id = user.logged? ? user.id : 0
    {
      :conditions => ["(#{table_name}.project_id IS NULL OR (#{base})) AND (#{table_name}.is_public = ? OR #{table_name}.user_id = ?)", true, user_id],
      :include => :project
    }
  }

  def initialize(attributes = nil)
    super attributes
    self.filters ||= { 'status_id' => {:operator => "o", :values => [""]} }
  end

  def after_initialize
    # Store the fact that project is nil (used in #editable_by?)
    @is_for_all = project.nil?
  end

  def validate_query_filters
    filters.each_key do |field|
      if values_for(field)
        case type_for(field)
        when :integer
          errors.add(label_for(field), :invalid) if values_for(field).detect {|v| v.present? && !v.match(/^\d+$/) }
        when :float
          errors.add(label_for(field), :invalid) if values_for(field).detect {|v| v.present? && !v.match(/^\d+(\.\d*)?$/) }
        when :date, :date_past
          case operator_for(field)
          when "=", ">=", "<=", "><"
            errors.add(label_for(field), :invalid) if values_for(field).detect {|v| v.present? && (!v.match(/^\d{4}-\d{2}-\d{2}$/) || (Date.parse(v) rescue nil).nil?) }
          when ">t-", "<t-", "t-"
            errors.add(label_for(field), :invalid) if values_for(field).detect {|v| v.present? && !v.match(/^\d+$/) }
          end
        end
      end

      errors.add label_for(field), :blank unless
          # filter requires one or more values
          (values_for(field) and !values_for(field).first.blank?) or
          # filter doesn't require any value
          ["o", "c", "!*", "*", "t", "w"].include? operator_for(field)
    end if filters
  end

  # Returns true if the query is visible to +user+ or the current user.
  def visible?(user=User.current)
    (project.nil? || user.allowed_to?(:view_issues, project)) && (self.is_public? || self.user_id == user.id)
  end

  def editable_by?(user)
    return false unless user
    # Admin can edit them all and regular users can edit their private queries
    return true if user.admin? || (!is_public && self.user_id == user.id)
    # Members can not edit public queries that are for all project (only admin is allowed to)
    is_public && !@is_for_all && user.allowed_to?(:manage_public_queries, project)
  end

  def available_filters
    return @available_filters if @available_filters

    trackers = project.nil? ? Tracker.find(:all, :order => 'position') : project.rolled_up_trackers

    @available_filters = { "status_id" => { :type => :list_status, :order => 1, :values => IssueStatus.find(:all, :order => 'position').collect{|s| [s.name, s.id.to_s] } },
                           "tracker_id" => { :type => :list, :order => 2, :values => trackers.collect{|s| [s.name, s.id.to_s] } },
                           "priority_id" => { :type => :list, :order => 3, :values => IssuePriority.all.collect{|s| [s.name, s.id.to_s] } },
                           "subject" => { :type => :text, :order => 8 },
                           "created_on" => { :type => :date_past, :order => 9 },
                           "updated_on" => { :type => :date_past, :order => 10 },
                           "start_date" => { :type => :date, :order => 11 },
                           "due_date" => { :type => :date, :order => 12 },
                           "estimated_hours" => { :type => :float, :order => 13 },
                           "done_ratio" =>  { :type => :integer, :order => 14 }}

    principals = []
    if project
      principals += project.principals.sort
    else
      all_projects = Project.visible.all
      if all_projects.any?
        # members of visible projects
        principals += Principal.active.find(:all, :conditions => ["#{User.table_name}.id IN (SELECT DISTINCT user_id FROM members WHERE project_id IN (?))", all_projects.collect(&:id)]).sort

        # project filter
        project_values = []
        Project.project_tree(all_projects) do |p, level|
          prefix = (level > 0 ? ('--' * level + ' ') : '')
          project_values << ["#{prefix}#{p.name}", p.id.to_s]
        end
        @available_filters["project_id"] = { :type => :list, :order => 1, :values => project_values} unless project_values.empty?
      end
    end
    users = principals.select {|p| p.is_a?(User)}

    assigned_to_values = []
    assigned_to_values << ["<< #{l(:label_me)} >>", "me"] if User.current.logged?
    assigned_to_values += (Setting.issue_group_assignment? ? principals : users).collect{|s| [s.name, s.id.to_s] }
    @available_filters["assigned_to_id"] = { :type => :list_optional, :order => 4, :values => assigned_to_values } unless assigned_to_values.empty?

    author_values = []
    author_values << ["<< #{l(:label_me)} >>", "me"] if User.current.logged?
    author_values += users.collect{|s| [s.name, s.id.to_s] }
    @available_filters["author_id"] = { :type => :list, :order => 5, :values => author_values } unless author_values.empty?

    group_values = Group.all.collect {|g| [g.name, g.id.to_s] }
    @available_filters["member_of_group"] = { :type => :list_optional, :order => 6, :values => group_values } unless group_values.empty?

    role_values = Role.givable.collect {|r| [r.name, r.id.to_s] }
    @available_filters["assigned_to_role"] = { :type => :list_optional, :order => 7, :values => role_values } unless role_values.empty?

    if User.current.logged?
      @available_filters["watcher_id"] = { :type => :list, :order => 15, :values => [["<< #{l(:label_me)} >>", "me"]] }
    end

    if project
      # project specific filters
      categories = project.issue_categories.all
      unless categories.empty?
        @available_filters["category_id"] = { :type => :list_optional, :order => 6, :values => categories.collect{|s| [s.name, s.id.to_s] } }
      end
      versions = project.shared_versions.all
      unless versions.empty?
        @available_filters["fixed_version_id"] = { :type => :list_optional, :order => 7, :values => versions.sort.collect{|s| ["#{s.project.name} - #{s.name}", s.id.to_s] } }
      end
      unless project.leaf?
        subprojects = project.descendants.visible.all
        unless subprojects.empty?
          @available_filters["subproject_id"] = { :type => :list_subprojects, :order => 13, :values => subprojects.collect{|s| [s.name, s.id.to_s] } }
        end
      end
      add_custom_fields_filters(project.all_issue_custom_fields)
    else
      # global filters for cross project issue list
      system_shared_versions = Version.visible.find_all_by_sharing('system')
      unless system_shared_versions.empty?
        @available_filters["fixed_version_id"] = { :type => :list_optional, :order => 7, :values => system_shared_versions.sort.collect{|s| ["#{s.project.name} - #{s.name}", s.id.to_s] } }
      end
      add_custom_fields_filters(IssueCustomField.find(:all, :conditions => {:is_filter => true, :is_for_all => true}))
    end
    @available_filters
  end

  def add_filter(field, operator, values)
    # values must be an array
    return unless values.nil? || values.is_a?(Array)
    # check if field is defined as an available filter
    if available_filters.has_key? field
      filter_options = available_filters[field]
      # check if operator is allowed for that filter
      #if @@operators_by_filter_type[filter_options[:type]].include? operator
      #  allowed_values = values & ([""] + (filter_options[:values] || []).collect {|val| val[1]})
      #  filters[field] = {:operator => operator, :values => allowed_values } if (allowed_values.first and !allowed_values.first.empty?) or ["o", "c", "!*", "*", "t"].include? operator
      #end
      filters[field] = {:operator => operator, :values => (values || [''])}
    end
  end

  def add_short_filter(field, expression)
    return unless expression && available_filters.has_key?(field)
    field_type = available_filters[field][:type]
    @@operators_by_filter_type[field_type].sort.reverse.detect do |operator|
      next unless expression =~ /^#{Regexp.escape(operator)}(.*)$/
      add_filter field, operator, $1.present? ? $1.split('|') : ['']
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
    label ||= field.gsub(/\_id$/, "")
  end

  def available_columns
    return @available_columns if @available_columns
    @available_columns = ::Query.available_columns
    @available_columns += (project ?
                            project.all_issue_custom_fields :
                            IssueCustomField.find(:all)
                           ).collect {|cf| QueryCustomFieldColumn.new(cf) }
  end

  def self.available_columns=(v)
    self.available_columns = (v)
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
    {'id' => "#{Issue.table_name}.id"}.merge(available_columns.inject({}) {|h, column|
                                               h[column.name.to_s] = column.sortable
                                               h
                                             })
  end

  def columns
    # preserve the column_names order
    (has_default_columns? ? default_columns_names : column_names).collect do |name|
       available_columns.find { |col| col.name == name }
    end.compact
  end

  def default_columns_names
    @default_columns_names ||= begin
      default_columns = Setting.issue_list_default_columns.map(&:to_sym)

      project.present? ? default_columns : [:project] | default_columns
    end
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
    column_names && column_names.include?(column.name)
  end

  def has_default_columns?
    column_names.nil? || column_names.empty?
  end

  def sort_criteria=(arg)
    c = []
    if arg.is_a?(Hash)
      arg = arg.keys.sort.collect {|k| arg[k]}
    end
    c = arg.select {|k,o| !k.to_s.blank?}.slice(0,3).collect {|k,o| [k.to_s, o == 'desc' ? o : 'asc']}
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

  # Returns the SQL sort order that should be prepended for grouping
  def group_by_sort_order
    if grouped? && (column = group_by_column)
      column.sortable.is_a?(Array) ?
        column.sortable.collect {|s| "#{s} #{column.default_order}"}.join(',') :
        "#{column.sortable} #{column.default_order}"
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

      # "me" value subsitution
      if %w(assigned_to_id author_id watcher_id).include?(field)
        if v.delete("me")
          if User.current.logged?
            v.push(User.current.id.to_s)
            v += User.current.group_ids.map(&:to_s) if field == 'assigned_to_id'
          else
            v.push("0")
          end
        end
      end

      if field =~ /^cf_(\d+)$/
        # custom field
        filters_clauses << sql_for_custom_field(field, operator, v, $1)
      elsif respond_to?("sql_for_#{field}_field")
        # specific statement
        filters_clauses << send("sql_for_#{field}_field", field, operator, v)
      else
        # regular field
        filters_clauses << '(' + sql_for_field(field, operator, v, Issue.table_name, field) + ')'
      end
    end if filters and valid?

    filters_clauses << project_statement
    filters_clauses.reject!(&:blank?)

    filters_clauses.any? ? filters_clauses.join(' AND ') : nil
  end

  # Returns the issue count
  def issue_count
    Issue.visible.count(:include => [:status, :project], :conditions => statement)
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  # Returns the issue count by group or nil if query is not grouped
  def issue_count_by_group
    r = nil
    if grouped?
      begin
        # Rails will raise an (unexpected) RecordNotFound if there's only a nil group value
        r = Issue.visible.count(:group => group_by_statement, :include => [:status, :project], :conditions => statement)
      rescue ActiveRecord::RecordNotFound
        r = {nil => issue_count}
      end
      c = group_by_column
      if c.is_a?(QueryCustomFieldColumn)
        r = r.keys.inject({}) {|h, k| h[c.custom_field.cast_value(k)] = r[k]; h}
      end
    end
    r
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  # Returns the issues
  # Valid options are :order, :offset, :limit, :include, :conditions
  def issues(options={})
    order_option = [group_by_sort_order, options[:order]].reject {|s| s.blank?}.join(',')
    order_option = nil if order_option.blank?
    
    joins = (order_option && order_option.include?('authors')) ? "LEFT OUTER JOIN users authors ON authors.id = #{Issue.table_name}.author_id" : nil

    Issue.visible.scoped(:conditions => options[:conditions]).find :all, :include => ([:status, :project] + (options[:include] || [])).uniq,
                     :conditions => statement,
                     :order => order_option,
                     :joins => joins,
                     :limit  => options[:limit],
                     :offset => options[:offset]
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  # Returns the journals
  # Valid options are :order, :offset, :limit
  def journals(options={})
    Journal.visible.find :all, :include => [:details, :user, {:issue => [:project, :author, :tracker, :status]}],
                       :conditions => statement,
                       :order => options[:order],
                       :limit => options[:limit],
                       :offset => options[:offset]
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  # Returns the versions
  # Valid options are :conditions
  def versions(options={})
    Version.visible.scoped(:conditions => options[:conditions]).find :all, :include => :project, :conditions => project_statement
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  def sql_for_watcher_id_field(field, operator, value)
    db_table = Watcher.table_name
    "#{Issue.table_name}.id #{ operator == '=' ? 'IN' : 'NOT IN' } (SELECT #{db_table}.watchable_id FROM #{db_table} WHERE #{db_table}.watchable_type='Issue' AND " +
      sql_for_field(field, '=', value, db_table, 'user_id') + ')'
  end

  def sql_for_member_of_group_field(field, operator, value)
    if operator == '*' # Any group
      groups = Group.all
      operator = '=' # Override the operator since we want to find by assigned_to
    elsif operator == "!*"
      groups = Group.all
      operator = '!' # Override the operator since we want to find by assigned_to
    else
      groups = Group.find_all_by_id(value)
    end
    groups ||= []

    members_of_groups = groups.inject([]) {|user_ids, group|
      if group && group.user_ids.present?
        user_ids << group.user_ids
      end
      user_ids.flatten.uniq.compact
    }.sort.collect(&:to_s)

    '(' + sql_for_field("assigned_to_id", operator, members_of_groups, Issue.table_name, "assigned_to_id", false) + ')'
  end

  def sql_for_assigned_to_role_field(field, operator, value)
    case operator
    when "*", "!*" # Member / Not member
      sw = operator == "!*" ? 'NOT' : ''
      nl = operator == "!*" ? "#{Issue.table_name}.assigned_to_id IS NULL OR" : ''
      "(#{nl} #{Issue.table_name}.assigned_to_id #{sw} IN (SELECT DISTINCT #{Member.table_name}.user_id FROM #{Member.table_name}" +
        " WHERE #{Member.table_name}.project_id = #{Issue.table_name}.project_id))"
    when "=", "!"
      role_cond = value.any? ? 
        "#{MemberRole.table_name}.role_id IN (" + value.collect{|val| "'#{connection.quote_string(val)}'"}.join(",") + ")" :
        "1=0"
      
      sw = operator == "!" ? 'NOT' : ''
      nl = operator == "!" ? "#{Issue.table_name}.assigned_to_id IS NULL OR" : ''
      "(#{nl} #{Issue.table_name}.assigned_to_id #{sw} IN (SELECT DISTINCT #{Member.table_name}.user_id FROM #{Member.table_name}, #{MemberRole.table_name}" +
        " WHERE #{Member.table_name}.project_id = #{Issue.table_name}.project_id AND #{Member.table_name}.id = #{MemberRole.table_name}.member_id AND #{role_cond}))"
    end
  end

  private

  def sql_for_custom_field(field, operator, value, custom_field_id)
    db_table = CustomValue.table_name
    db_field = 'value'
    "#{Issue.table_name}.id IN (SELECT #{Issue.table_name}.id FROM #{Issue.table_name} LEFT OUTER JOIN #{db_table} ON #{db_table}.customized_type='Issue' AND #{db_table}.customized_id=#{Issue.table_name}.id AND #{db_table}.custom_field_id=#{custom_field_id} WHERE " +
      sql_for_field(field, operator, value, db_table, db_field, true) + ')'
  end

  # Helper method to generate the WHERE sql for a +field+, +operator+ and a +value+
  def sql_for_field(field, operator, value, db_table, db_field, is_custom_filter=false)
    sql = ''
    case operator
    when "="
      if value.any?
        case type_for(field)
        when :date, :date_past
          sql = date_clause(db_table, db_field, (Date.parse(value.first) rescue nil), (Date.parse(value.first) rescue nil))
        when :integer
          sql = "#{db_table}.#{db_field} = #{value.first.to_i}"
        when :float
          sql = "#{db_table}.#{db_field} BETWEEN #{value.first.to_f - 1e-5} AND #{value.first.to_f + 1e-5}"
        else
          sql = "#{db_table}.#{db_field} IN (" + value.collect{|val| "'#{connection.quote_string(val)}'"}.join(",") + ")"
        end
      else
        # IN an empty set
        sql = "1=0"
      end
    when "!"
      if value.any?
        sql = "(#{db_table}.#{db_field} IS NULL OR #{db_table}.#{db_field} NOT IN (" + value.collect{|val| "'#{connection.quote_string(val)}'"}.join(",") + "))"
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
        sql = date_clause(db_table, db_field, (Date.parse(value.first) rescue nil), nil)
      else
        if is_custom_filter
          sql = "CAST(#{db_table}.#{db_field} AS decimal(60,3)) >= #{value.first.to_f}"
        else
          sql = "#{db_table}.#{db_field} >= #{value.first.to_f}"
        end
      end
    when "<="
      if [:date, :date_past].include?(type_for(field))
        sql = date_clause(db_table, db_field, nil, (Date.parse(value.first) rescue nil))
      else
        if is_custom_filter
          sql = "CAST(#{db_table}.#{db_field} AS decimal(60,3)) <= #{value.first.to_f}"
        else
          sql = "#{db_table}.#{db_field} <= #{value.first.to_f}"
        end
      end
    when "><"
      if [:date, :date_past].include?(type_for(field))
        sql = date_clause(db_table, db_field, (Date.parse(value[0]) rescue nil), (Date.parse(value[1]) rescue nil))
      else
        if is_custom_filter
          sql = "CAST(#{db_table}.#{db_field} AS decimal(60,3)) BETWEEN #{value[0].to_f} AND #{value[1].to_f}"
        else
          sql = "#{db_table}.#{db_field} BETWEEN #{value[0].to_f} AND #{value[1].to_f}"
        end
      end
    when "o"
      sql = "#{IssueStatus.table_name}.is_closed=#{connection.quoted_false}" if field == "status_id"
    when "c"
      sql = "#{IssueStatus.table_name}.is_closed=#{connection.quoted_true}" if field == "status_id"
    when ">t-"
      sql = relative_date_clause(db_table, db_field, - value.first.to_i, 0)
    when "<t-"
      sql = relative_date_clause(db_table, db_field, nil, - value.first.to_i)
    when "t-"
      sql = relative_date_clause(db_table, db_field, - value.first.to_i, - value.first.to_i)
    when ">t+"
      sql = relative_date_clause(db_table, db_field, value.first.to_i, nil)
    when "<t+"
      sql = relative_date_clause(db_table, db_field, 0, value.first.to_i)
    when "t+"
      sql = relative_date_clause(db_table, db_field, value.first.to_i, value.first.to_i)
    when "t"
      sql = relative_date_clause(db_table, db_field, 0, 0)
    when "w"
      first_day_of_week = l(:general_first_day_of_week).to_i
      day_of_week = Date.today.cwday
      days_ago = (day_of_week >= first_day_of_week ? day_of_week - first_day_of_week : day_of_week + 7 - first_day_of_week)
      sql = relative_date_clause(db_table, db_field, - days_ago, - days_ago + 6)
    when "~"
      sql = "LOWER(#{db_table}.#{db_field}) LIKE '%#{connection.quote_string(value.first.to_s.downcase)}%'"
    when "!~"
      sql = "LOWER(#{db_table}.#{db_field}) NOT LIKE '%#{connection.quote_string(value.first.to_s.downcase)}%'"
    else
      raise "Unknown query operator #{operator}"
    end

    return sql
  end

  def add_custom_fields_filters(custom_fields)
    @available_filters ||= {}

    custom_fields.select(&:is_filter?).each do |field|
      case field.field_format
      when "text"
        options = { :type => :text, :order => 20 }
      when "list"
        options = { :type => :list_optional, :values => field.possible_values, :order => 20}
      when "date"
        options = { :type => :date, :order => 20 }
      when "bool"
        options = { :type => :list, :values => [[l(:general_text_yes), "1"], [l(:general_text_no), "0"]], :order => 20 }
      when "int"
        options = { :type => :integer, :order => 20 }
      when "float"
        options = { :type => :float, :order => 20 }
      when "user", "version"
        next unless project
        options = { :type => :list_optional, :values => field.possible_values_options(project), :order => 20}
      else
        options = { :type => :string, :order => 20 }
      end
      @available_filters["cf_#{field.id}"] = options.merge({ :name => field.name })
    end
  end

  # Returns a SQL clause for a date or datetime field.
  def date_clause(table, field, from, to)
    s = []
    if from
      from_yesterday = from - 1
      from_yesterday_utc = Time.gm(from_yesterday.year, from_yesterday.month, from_yesterday.day)
      s << ("#{table}.#{field} > '%s'" % [connection.quoted_date(from_yesterday_utc.end_of_day)])
    end
    if to
      to_utc = Time.gm(to.year, to.month, to.day)
      s << ("#{table}.#{field} <= '%s'" % [connection.quoted_date(to_utc.end_of_day)])
    end
    s.join(' AND ')
  end

  # Returns a SQL clause for a date or datetime field using relative dates.
  def relative_date_clause(table, field, days_from, days_to)
    date_clause(table, field, (days_from ? Date.today + days_from : nil), (days_to ? Date.today + days_to : nil))
  end
end
