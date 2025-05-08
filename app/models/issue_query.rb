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

class IssueQuery < Query
  self.queried_class = Issue
  self.view_permission = :view_issues

  ESTIMATED_REMAINING_HOURS_SQL = Arel.sql("COALESCE(#{Issue.table_name}.estimated_hours, 0) * (100 - COALESCE(#{Issue.table_name}.done_ratio, 0)) / 100")
  self.available_columns = [
    QueryColumn.new(:id, :sortable => "#{Issue.table_name}.id",
                    :default_order => 'desc', :caption => '#', :frozen => true),
    QueryColumn.new(:project, :sortable => "#{Project.table_name}.name", :groupable => true),
    QueryColumn.new(:tracker, :sortable => "#{Tracker.table_name}.position", :groupable => true),
    QueryColumn.new(:parent,
                    :sortable => ["#{Issue.table_name}.root_id", "#{Issue.table_name}.lft ASC"],
                    :default_order => 'desc', :caption => :field_parent_issue),
    QueryAssociationColumn.new(:parent, :subject, :caption => :field_parent_issue_subject),
    QueryColumn.new(:status, :sortable => "#{IssueStatus.table_name}.position", :groupable => true),
    QueryColumn.new(:priority, :sortable => "#{IssuePriority.table_name}.position",
                    :default_order => 'desc', :groupable => true),
    QueryColumn.new(:subject, :sortable => "#{Issue.table_name}.subject"),
    QueryColumn.new(:author,
                    :sortable => lambda {User.fields_for_order_statement("authors")},
                    :groupable => true),
    QueryColumn.new(:assigned_to,
                    :sortable => lambda {User.fields_for_order_statement},
                    :groupable => true),
    WatcherQueryColumn.new(:watcher_users, :caption => :label_issue_watchers),
    TimestampQueryColumn.new(:updated_on, :sortable => "#{Issue.table_name}.updated_on",
                             :default_order => 'desc', :groupable => true),
    QueryColumn.new(:category, :sortable => "#{IssueCategory.table_name}.name", :groupable => true),
    QueryColumn.new(:fixed_version, :sortable => lambda {Version.fields_for_order_statement},
                    :groupable => true),
    QueryColumn.new(:start_date, :sortable => "#{Issue.table_name}.start_date", :groupable => true),
    QueryColumn.new(:due_date, :sortable => "#{Issue.table_name}.due_date", :groupable => true),
    QueryColumn.new(:estimated_hours, :sortable => "#{Issue.table_name}.estimated_hours",
                    :totalable => true),
    QueryColumn.new(:estimated_remaining_hours,
                    :sortable => ESTIMATED_REMAINING_HOURS_SQL,
                    :totalable => true),
    QueryColumn.new(
      :total_estimated_hours,
      :sortable =>
        lambda do
          "COALESCE((SELECT SUM(estimated_hours) FROM #{Issue.table_name} subtasks" \
          " WHERE #{Issue.visible_condition(User.current).gsub(/\bissues\b/, 'subtasks')}" \
          " AND subtasks.root_id = #{Issue.table_name}.root_id" \
          " AND subtasks.lft >= #{Issue.table_name}.lft" \
          " AND subtasks.rgt <= #{Issue.table_name}.rgt), 0)"
        end,
      :default_order => 'desc'),
    QueryColumn.new(:done_ratio, :sortable => "#{Issue.table_name}.done_ratio", :groupable => true),
    TimestampQueryColumn.new(:created_on, :sortable => "#{Issue.table_name}.created_on",
                             :default_order => 'desc', :groupable => true),
    TimestampQueryColumn.new(:closed_on, :sortable => "#{Issue.table_name}.closed_on",
                             :default_order => 'desc', :groupable => true),
    QueryColumn.new(:last_updated_by,
                    :sortable => lambda {User.fields_for_order_statement("last_journal_user")}),
    QueryColumn.new(:relations, :caption => :label_related_issues),
    QueryColumn.new(:attachments, :caption => :label_attachment_plural),
    QueryColumn.new(:description, :inline => false),
    QueryColumn.new(:last_notes, :caption => :label_last_notes, :inline => false)
  ]

  has_many :projects, foreign_key: 'default_issue_query_id', dependent: :nullify, inverse_of: 'default_issue_query'
  after_update { projects.clear unless visibility == VISIBILITY_PUBLIC }
  scope :for_all_projects, ->{ where(project_id: nil) }

  def self.default(project: nil, user: User.current)
    # user default
    if user&.logged? && (query_id = user.pref.default_issue_query).present?
      query = find_by(id: query_id)
      return query if query&.visible?(user)
    end

    # project default
    query = project&.default_issue_query
    return query if query&.visibility == VISIBILITY_PUBLIC

    # global default
    if (query_id = Setting.default_issue_query).present?
      query = find_by(id: query_id)
      return query if query&.visibility == VISIBILITY_PUBLIC
    end
    nil
  end

  def initialize(attributes=nil, *args)
    super(attributes)
    self.filters ||= {'status_id' => {:operator => "o", :values => [""]}}
  end

  def draw_relations
    r = options[:draw_relations]
    r.nil? || r == '1'
  end

  def draw_relations=(arg)
    options[:draw_relations] = (arg == '0' ? '0' : nil)
  end

  def draw_progress_line
    r = options[:draw_progress_line]
    r == '1'
  end

  def draw_progress_line=(arg)
    options[:draw_progress_line] = (arg == '1' ? '1' : nil)
  end

  def draw_selected_columns
    r = options[:draw_selected_columns]
    r == '1'
  end

  def draw_selected_columns=(arg)
    options[:draw_selected_columns] = (arg == '1' ? '1' : nil)
  end

  def build_from_params(params, defaults={})
    super
    self.draw_relations =
      params[:draw_relations] ||
        (params[:query] && params[:query][:draw_relations]) || options[:draw_relations]
    self.draw_progress_line =
      params[:draw_progress_line] ||
        (params[:query] && params[:query][:draw_progress_line]) ||
        options[:draw_progress_line]
    self.draw_selected_columns =
      params[:draw_selected_columns] ||
        (params[:query] && params[:query][:draw_selected_columns]) ||
        options[:draw_progress_line]
    self
  end

  def initialize_available_filters
    add_available_filter(
      "status_id",
      :type => :list_status, :values => lambda {issue_statuses_values}
    )
    add_available_filter(
      "project_id",
      :type => :list, :values => lambda {project_values}
    ) if project.nil?
    add_available_filter(
      "tracker_id",
      :type => :list_with_history, :values => trackers.collect{|s| [s.name, s.id.to_s]}
    )
    add_available_filter(
      "priority_id",
      :type => :list_with_history,
      :values => IssuePriority.pluck(:name, :id).map {|name, id| [name, id.to_s]}
    )
    add_available_filter(
      "author_id",
      :type => :list, :values => lambda {author_values}
    )
    add_available_filter(
      "author.group",
      :type => :list,
      :values => lambda {Group.givable.visible.pluck(:name, :id).map {|name, id| [name, id.to_s]}},
      :name => l(:label_attribute_of_author, :name => l(:label_group))
    )
    add_available_filter(
      "author.role",
      :type => :list,
      :values => lambda {Role.givable.pluck(:name, :id).map {|name, id| [name, id.to_s]}},
      :name => l(:label_attribute_of_author, :name => l(:field_role))
    )
    add_available_filter(
      "assigned_to_id",
      :type => :list_optional_with_history, :values => lambda {assigned_to_values}
    )
    add_available_filter(
      "member_of_group",
      :type => :list_optional,
      :values => lambda {Group.givable.visible.pluck(:name, :id).map {|name, id| [name, id.to_s]}}
    )
    add_available_filter(
      "assigned_to_role",
      :type => :list_optional,
      :values => lambda {Role.givable.pluck(:name, :id).map {|name, id| [name, id.to_s]}}
    )
    add_available_filter(
      "fixed_version_id",
      :type => :list_optional_with_history, :values => lambda {fixed_version_values}
    )
    add_available_filter(
      "fixed_version.due_date",
      :type => :date,
      :name => l(:label_attribute_of_fixed_version, :name => l(:field_effective_date))
    )
    add_available_filter(
      "fixed_version.status",
      :type => :list,
      :name => l(:label_attribute_of_fixed_version, :name => l(:field_status)),
      :values => Version::VERSION_STATUSES.map{|s| [l("version_status_#{s}"), s]}
    )
    add_available_filter(
      "category_id",
      :type => :list_optional_with_history,
      :values => lambda {project.issue_categories.pluck(:name, :id).map {|name, id| [name, id.to_s]}}
    ) if project
    add_available_filter "subject", :type => :text
    add_available_filter "description", :type => :text
    add_available_filter "notes", :type => :text
    add_available_filter "created_on", :type => :date_past
    add_available_filter "updated_on", :type => :date_past
    add_available_filter "closed_on", :type => :date_past
    add_available_filter "start_date", :type => :date
    add_available_filter "due_date", :type => :date
    add_available_filter "estimated_hours", :type => :float

    if User.current.allowed_to?(:view_time_entries, project, :global => true)
      add_available_filter "spent_time", :type => :float, :label => :label_spent_time
    end

    add_available_filter "done_ratio", :type => :integer

    if User.current.allowed_to?(:set_issues_private, nil, :global => true) ||
      User.current.allowed_to?(:set_own_issues_private, nil, :global => true)
      add_available_filter(
        "is_private",
        :type => :list,
        :values => [[l(:general_text_yes), "1"], [l(:general_text_no), "0"]]
      )
    end
    add_available_filter(
      "attachment",
      :type => :text, :name => l(:label_attachment)
    )
    add_available_filter(
      "attachment_description",
      :type => :text, :name => l(:label_attachment_description)
    )
    if User.current.logged?
      add_available_filter(
        "watcher_id",
        :type => :list, :values => lambda {watcher_values}
      )
    end
    add_available_filter(
      "updated_by",
      :type => :list, :values => lambda {author_values}
    )
    add_available_filter(
      "last_updated_by",
      :type => :list, :values => lambda {author_values}
    )
    if project && !project.leaf?
      add_available_filter(
        "subproject_id",
        :type => :list_subprojects,
        :values => lambda {subproject_values}
      )
    end

    add_available_filter(
      "project.status",
      :type => :list,
      :name => l(:label_attribute_of_project, :name => l(:field_status)),
      :values => lambda {project_statuses_values}
    ) if project.nil? || !project.leaf?

    add_custom_fields_filters(issue_custom_fields)
    add_associations_custom_fields_filters :project, :author, :assigned_to, :fixed_version

    IssueRelation::TYPES.each do |relation_type, options|
      add_available_filter(
        relation_type, :type => :relation, :label => options[:name],
        :values => lambda {all_projects_values}
      )
    end
    add_available_filter "parent_id", :type => :tree, :label => :field_parent_issue
    add_available_filter "child_id", :type => :tree, :label => :label_subtask_plural

    add_available_filter "issue_id", :type => :integer, :label => :label_issue

    add_available_filter "any_searchable", :type => :search

    Tracker.disabled_core_fields(trackers).each do |field|
      delete_available_filter field
    end
  end

  def available_columns
    return @available_columns if @available_columns

    @available_columns = self.class.available_columns.dup
    @available_columns += issue_custom_fields.visible.collect {|cf| QueryCustomFieldColumn.new(cf)}

    if User.current.allowed_to?(:view_time_entries, project, :global => true)
      # insert the columns after total_estimated_hours or at the end
      index = @available_columns.find_index {|column| column.name == :total_estimated_hours}
      index = (index ? index + 1 : -1)

      subselect = "SELECT SUM(hours) FROM #{TimeEntry.table_name}" +
        " JOIN #{Project.table_name} ON #{Project.table_name}.id = #{TimeEntry.table_name}.project_id" +
        " WHERE (#{TimeEntry.visible_condition(User.current)}) AND #{TimeEntry.table_name}.issue_id = #{Issue.table_name}.id"

      @available_columns.insert(
        index,
        QueryColumn.new(:spent_hours,
                        :sortable => "COALESCE((#{subselect}), 0)",
                        :default_order => 'desc',
                        :caption => :label_spent_time,
                        :totalable => true)
      )

      subselect = "SELECT SUM(hours) FROM #{TimeEntry.table_name}" +
        " JOIN #{Project.table_name} ON #{Project.table_name}.id = #{TimeEntry.table_name}.project_id" +
        " JOIN #{Issue.table_name} subtasks ON subtasks.id = #{TimeEntry.table_name}.issue_id" +
        " WHERE (#{TimeEntry.visible_condition(User.current)})" +
        " AND subtasks.root_id = #{Issue.table_name}.root_id AND subtasks.lft >= #{Issue.table_name}.lft AND subtasks.rgt <= #{Issue.table_name}.rgt"

      @available_columns.insert(
        index + 1,
        QueryColumn.new(:total_spent_hours,
                        :sortable => "COALESCE((#{subselect}), 0)",
                        :default_order => 'desc',
                        :caption => :label_total_spent_time)
      )
    end

    if User.current.allowed_to?(:set_issues_private, nil, :global => true) ||
      User.current.allowed_to?(:set_own_issues_private, nil, :global => true)
      @available_columns <<
        QueryColumn.new(:is_private,
                        :sortable => "#{Issue.table_name}.is_private", :groupable => true)
    end

    disabled_fields = Tracker.disabled_core_fields(trackers).map {|field| field.delete_suffix('_id')}
    if disabled_fields.include?("estimated_hours")
      disabled_fields += %w[total_estimated_hours estimated_remaining_hours]
    end
    @available_columns.reject! do |column|
      disabled_fields.include?(column.name.to_s)
    end

    @available_columns
  end

  def default_columns_names
    @default_columns_names ||= begin
      default_columns = Setting.issue_list_default_columns.map(&:to_sym)

      project.present? ? default_columns : [:project] | default_columns
    end
  end

  def default_totalable_names
    Setting.issue_list_default_totals.map(&:to_sym)
  end

  def default_sort_criteria
    [['id', 'desc']]
  end

  def base_scope
    Issue.visible.joins(:status, :project).where(statement)
  end

  # Returns the issue count
  def issue_count
    base_scope.count
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  # Returns sum of all the issue's estimated_hours
  def total_for_estimated_hours(scope)
    map_total(scope.sum(:estimated_hours)) {|t| t.to_f.round(2)}
  end

  def total_for_estimated_remaining_hours(scope)
    map_total(scope.sum(ESTIMATED_REMAINING_HOURS_SQL)) {|t| t.to_f.round(2)}
  end

  # Returns sum of all the issue's time entries hours
  def total_for_spent_hours(scope)
    total = scope.joins(:time_entries).
      where(TimeEntry.visible_condition(User.current)).
      sum("#{TimeEntry.table_name}.hours")

    map_total(total) {|t| t.to_f.round(2)}
  end

  # Returns the issues
  # Valid options are :order, :offset, :limit, :include, :conditions
  def issues(options={})
    order_option = [group_by_sort_order, (options[:order] || sort_clause)].flatten.reject(&:blank?)
    # The default order of IssueQuery is issues.id DESC(by IssueQuery#default_sort_criteria)
    unless ["#{Issue.table_name}.id ASC", "#{Issue.table_name}.id DESC"].any?{|i| order_option.include?(i)}
      order_option << "#{Issue.table_name}.id DESC"
    end

    scope = base_scope.
      preload(:priority).
      includes(([:status, :project] + (options[:include] || [])).uniq).
      where(options[:conditions]).
      order(order_option).
      joins(joins_for_order_statement(order_option.join(','))).
      limit(options[:limit]).
      offset(options[:offset])

    scope =
      scope.preload(
        [:tracker, :author, :assigned_to, :fixed_version,
         :category, :attachments] & columns.map(&:name)
      )
    if has_custom_field_column?
      scope = scope.preload(:custom_values)
    end
    if has_column?(:watcher_users)
      scope = scope.preload(:watcher_users)
    end

    issues = scope.to_a

    if has_column?(:spent_hours)
      Issue.load_visible_spent_hours(issues)
    end
    if has_column?(:total_spent_hours)
      Issue.load_visible_total_spent_hours(issues)
    end
    if has_column?(:last_updated_by)
      Issue.load_visible_last_updated_by(issues)
    end
    if has_column?(:relations)
      Issue.load_visible_relations(issues)
    end
    if has_column?(:last_notes)
      Issue.load_visible_last_notes(issues)
    end
    issues
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  # Returns the issues ids
  def issue_ids(options={})
    order_option = [group_by_sort_order, (options[:order] || sort_clause)].flatten.reject(&:blank?)
    # The default order of IssueQuery is issues.id DESC(by IssueQuery#default_sort_criteria)
    unless ["#{Issue.table_name}.id ASC", "#{Issue.table_name}.id DESC"].any?{|i| order_option.include?(i)}
      order_option << "#{Issue.table_name}.id DESC"
    end

    base_scope.
      includes(([:status, :project] + (options[:include] || [])).uniq).
      references(([:status, :project] + (options[:include] || [])).uniq).
      where(options[:conditions]).
      order(order_option).
      joins(joins_for_order_statement(order_option.join(','))).
      limit(options[:limit]).
      offset(options[:offset]).
      pluck(:id)
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  # Returns the journals
  # Valid options are :order, :offset, :limit
  def journals(options={})
    Journal.visible.
      joins(:issue => [:project, :status]).
      where(statement).
      order(options[:order]).
      limit(options[:limit]).
      offset(options[:offset]).
      preload(:details, :user, {:issue => [:project, :author, :tracker, :status]}).
      to_a
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  # Returns the versions
  # Valid options are :conditions
  def versions(options={})
    Version.visible.
      where(project_statement).
      where(options[:conditions]).
      includes(:project).
      references(:project).
      to_a
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  def sql_for_notes_field(field, operator, value)
    subquery = "SELECT 1 FROM #{Journal.table_name}" +
      " WHERE #{Journal.table_name}.journalized_type='Issue' AND #{Journal.table_name}.journalized_id=#{Issue.table_name}.id" +
      " AND (#{sql_for_field field, operator.delete_prefix('!'), value, Journal.table_name, 'notes'})" +
      " AND (#{Journal.visible_notes_condition(User.current, :skip_pre_condition => true)})"
    "#{operator.start_with?('!') ? "NOT EXISTS" : "EXISTS"} (#{subquery})"
  end

  def sql_for_updated_by_field(field, operator, value)
    neg = (operator == '!' ? 'NOT' : '')
    subquery = "SELECT 1 FROM #{Journal.table_name}" +
      " WHERE #{Journal.table_name}.journalized_type='Issue' AND #{Journal.table_name}.journalized_id=#{Issue.table_name}.id" +
      " AND (#{sql_for_field field, '=', value, Journal.table_name, 'user_id'})" +
      " AND (#{Journal.visible_notes_condition(User.current, :skip_pre_condition => true)})"

    "#{neg} EXISTS (#{subquery})"
  end

  def sql_for_last_updated_by_field(field, operator, value)
    neg = (operator == '!' ? 'NOT' : '')
    subquery = "SELECT 1 FROM #{Journal.table_name} sj" +
      " WHERE sj.journalized_type='Issue' AND sj.journalized_id=#{Issue.table_name}.id AND (#{sql_for_field field, '=', value, 'sj', 'user_id'})" +
      " AND sj.id IN (SELECT MAX(#{Journal.table_name}.id) FROM #{Journal.table_name}" +
      "   WHERE #{Journal.table_name}.journalized_type='Issue' AND #{Journal.table_name}.journalized_id=#{Issue.table_name}.id" +
      "   AND (#{Journal.visible_notes_condition(User.current, :skip_pre_condition => true)}))"

    "#{neg} EXISTS (#{subquery})"
  end

  def sql_for_spent_time_field(field, operator, value)
    first, second = value.first.to_f, value.second.to_f
    sql_op =
      case operator
      when "=", ">=", "<=" then  "#{operator} #{first}"
      when "><"            then  "BETWEEN #{first} AND #{second}"
      when "*"             then  "> 0"
      when "!*"            then  "= 0"
      else
        return nil
      end
    "COALESCE((" +
      "SELECT ROUND(CAST(SUM(hours) AS DECIMAL(30,3)), 2) " +
      "FROM #{TimeEntry.table_name} " +
      "WHERE issue_id = #{Issue.table_name}.id), 0) #{sql_op}"
  end

  def sql_for_watcher_id_field(field, operator, value)
    db_table = Watcher.table_name
    me_ids = [0, User.current.id]
    me_ids.concat(User.current.groups.pluck(:id))
    me, others = value.partition {|id| me_ids.include?(id.to_i)}
    sql =
      if others.any?
        "SELECT #{Issue.table_name}.id FROM #{Issue.table_name} " +
        "INNER JOIN #{db_table} ON #{Issue.table_name}.id = #{db_table}.watchable_id AND #{db_table}.watchable_type = 'Issue' " +
        "LEFT OUTER JOIN #{Project.table_name} ON #{Project.table_name}.id = #{Issue.table_name}.project_id " +
        "WHERE (" +
          sql_for_field(field, '=', me, db_table, 'user_id') +
        ') OR (' +
          Project.allowed_to_condition(User.current, :view_issue_watchers) +
          ' AND ' +
          sql_for_field(field, '=', others, db_table, 'user_id') +
        ')'
      else
        "SELECT #{db_table}.watchable_id FROM #{db_table} " +
        "WHERE #{db_table}.watchable_type='Issue' AND " +
        sql_for_field(field, '=', me, db_table, 'user_id')
      end
    "#{Issue.table_name}.id #{ operator == '=' ? 'IN' : 'NOT IN' } (#{sql})"
  end

  def sql_for_member_of_group_field(field, operator, value)
    if operator == '*' # Any group
      groups = Group.givable
      operator = '=' # Override the operator since we want to find by assigned_to
    elsif operator == "!*"
      groups = Group.givable
      operator = '!' # Override the operator since we want to find by assigned_to
    else
      groups = Group.where(:id => value).to_a
    end
    groups ||= []

    members_of_groups = groups.inject([]) do |user_ids, group|
      user_ids + group.user_ids + [group.id]
    end.uniq.compact.sort.collect(&:to_s)

    '(' + sql_for_field("assigned_to_id", operator, members_of_groups, Issue.table_name, "assigned_to_id", false) + ')'
  end

  def sql_for_assigned_to_role_field(field, operator, value)
    case operator
    when "*", "!*" # Member / Not member
      sw = operator == "!*" ? 'NOT' : ''
      nl = operator == "!*" ? "#{Issue.table_name}.assigned_to_id IS NULL OR" : ''

      subquery =
        "SELECT 1" +
        " FROM #{Member.table_name}" +
        " WHERE #{Issue.table_name}.project_id = #{Member.table_name}.project_id AND #{Member.table_name}.user_id = #{Issue.table_name}.assigned_to_id"
      "(#{nl} #{sw} EXISTS (#{subquery}))"
    when "=", "!"
      role_cond =
        if value.any?
          "#{MemberRole.table_name}.role_id IN (" + value.collect{|val| "'#{self.class.connection.quote_string(val)}'"}.join(",") + ")"
        else
          "1=0"
        end
      sw = operator == "!" ? 'NOT' : ''
      nl = operator == "!" ? "#{Issue.table_name}.assigned_to_id IS NULL OR" : ''
      subquery =
        "SELECT 1" +
        " FROM #{Member.table_name} inner join #{MemberRole.table_name} on members.id = member_roles.member_id" +
        " WHERE #{Issue.table_name}.project_id = #{Member.table_name}.project_id AND #{Member.table_name}.user_id = #{Issue.table_name}.assigned_to_id AND #{role_cond}"
      "(#{nl} #{sw} EXISTS (#{subquery}))"
    end
  end

  def sql_for_author_group_field(field, operator, value)
    groups = value.empty? ? Group.givable : Group.where(:id => value).to_a

    author_groups = groups.inject([]) do |user_ids, group|
      user_ids + group.user_ids + [group.id]
    end.uniq.compact.sort.collect(&:to_s)

    '(' + sql_for_field("author_id", operator, author_groups, Issue.table_name, "author_id", false) + ')'
  end

  def sql_for_author_role_field(field, operator, value)
    role_cond =
      if value.any?
        "#{MemberRole.table_name}.role_id IN (" + value.collect{|val| "'#{self.class.connection.quote_string(val)}'"}.join(",") + ")"
      else
        "1=0"
      end
    sw = operator == "!" ? 'NOT' : ''
    nl = operator == "!" ? "#{Issue.table_name}.author_id IS NULL OR" : ''
    subquery =
      "SELECT 1" +
      " FROM #{Member.table_name} inner join #{MemberRole.table_name} on members.id = member_roles.member_id" +
      " WHERE #{Issue.table_name}.project_id = #{Member.table_name}.project_id AND #{Member.table_name}.user_id = #{Issue.table_name}.author_id AND #{role_cond}"
    "(#{nl} #{sw} EXISTS (#{subquery}))"
  end

  def sql_for_fixed_version_status_field(field, operator, value)
    where = sql_for_field(field, operator, value, Version.table_name, "status")
    version_id_scope = project ? project.shared_versions : Version.visible
    version_ids = version_id_scope.where(where).pluck(:id)

    nl = operator == "!" ? "#{Issue.table_name}.fixed_version_id IS NULL OR" : ''
    "(#{nl} #{sql_for_field("fixed_version_id", "=", version_ids, Issue.table_name, "fixed_version_id")})"
  end

  def sql_for_fixed_version_due_date_field(field, operator, value)
    where = sql_for_field(field, operator, value, Version.table_name, "effective_date")
    version_id_scope = project ? project.shared_versions : Version.visible
    version_ids = version_id_scope.where(where).pluck(:id)

    nl = operator == "!*" ? "#{Issue.table_name}.fixed_version_id IS NULL OR" : ''
    "(#{nl} #{sql_for_field("fixed_version_id", "=", version_ids, Issue.table_name, "fixed_version_id")})"
  end

  def sql_for_is_private_field(field, operator, value)
    op = (operator == "=" ? 'IN' : 'NOT IN')
    va =
      value.map do |v|
        v == '0' ? self.class.connection.quoted_false : self.class.connection.quoted_true
      end.uniq.join(',')
    "#{Issue.table_name}.is_private #{op} (#{va})"
  end

  def sql_for_attachment_field(field, operator, value)
    case operator
    when "*", "!*"
      e = (operator == "*" ? "EXISTS" : "NOT EXISTS")
      "#{e} (SELECT 1 FROM #{Attachment.table_name} a WHERE a.container_type = 'Issue' AND a.container_id = #{Issue.table_name}.id)"
    when "~", "!~", "*~"
      c = sql_contains("a.filename", value.first, :all_words => (operator != "*~"))
      e = (operator == "!~" ? "NOT EXISTS" : "EXISTS")
      "#{e} (SELECT 1 FROM #{Attachment.table_name} a WHERE a.container_type = 'Issue' AND a.container_id = #{Issue.table_name}.id AND (#{c}))"
    when "^", "$"
      c = sql_contains("a.filename", value.first, (operator == "^" ? :starts_with : :ends_with) => true)
      "EXISTS (SELECT 1 FROM #{Attachment.table_name} a WHERE a.container_type = 'Issue' AND a.container_id = #{Issue.table_name}.id AND (#{c}))"
    end
  end

  def sql_for_attachment_description_field(field, operator, value)
    cond_description = "a.description IS NOT NULL AND a.description <> ''"
    c =
      case operator
      when '*', '!*'
        (operator == '*' ? cond_description : "NOT (#{cond_description})")
      when '~', '!~', '*~'
        (operator == '~' ? '' : "#{cond_description} AND ") +
        sql_contains('a.description', value.first, :match => (operator != '!~'), :all_words => (operator != '*~'))
      when '^', '$'
        sql_contains('a.description', value.first, (operator == '^' ? :starts_with : :ends_with) => true)
      else
        '1=0'
      end
    "EXISTS (SELECT 1 FROM #{Attachment.table_name} a WHERE a.container_type = 'Issue' AND a.container_id = #{Issue.table_name}.id AND (#{c}))"
  end

  def sql_for_parent_id_field(field, operator, value)
    case operator
    when "="
      # accepts a comma separated list of ids
      ids = value.first.to_s.scan(/\d+/).map(&:to_i).uniq
      if ids.present?
        "#{Issue.table_name}.parent_id IN (#{ids.join(",")})"
      else
        "1=0"
      end
    when "~"
      ids = value.first.to_s.scan(/\d+/).map(&:to_i).uniq
      conditions = ids.filter_map do |id|
        root_id, lft, rgt = Issue.where(id: id).pick(:root_id, :lft, :rgt)
        if root_id && lft && rgt
          "(#{Issue.table_name}.root_id = #{root_id} AND #{Issue.table_name}.lft > #{lft} AND #{Issue.table_name}.rgt < #{rgt})"
        else
          nil
        end
      end

      if conditions.any?
        "(#{conditions.join(' OR ')})"
      else
        "1=0"
      end
    when "!*"
      "#{Issue.table_name}.parent_id IS NULL"
    when "*"
      "#{Issue.table_name}.parent_id IS NOT NULL"
    end
  end

  def sql_for_child_id_field(field, operator, value)
    case operator
    when "="
      # accepts a comma separated list of child ids
      child_ids = value.first.to_s.scan(/\d+/).map(&:to_i).uniq
      ids = Issue.where(:id => child_ids).pluck(:parent_id).compact.uniq
      if ids.present?
        "#{Issue.table_name}.id IN (#{ids.join(",")})"
      else
        "1=0"
      end
    when "~"
      root_id, lft, rgt = Issue.where(:id => value.first.to_i).pick(:root_id, :lft, :rgt)
      if root_id && lft && rgt
        "#{Issue.table_name}.root_id = #{root_id} AND #{Issue.table_name}.lft < #{lft} AND #{Issue.table_name}.rgt > #{rgt}"
      else
        "1=0"
      end
    when "!*"
      "#{Issue.table_name}.rgt - #{Issue.table_name}.lft = 1"
    when "*"
      "#{Issue.table_name}.rgt - #{Issue.table_name}.lft > 1"
    end
  end

  def sql_for_updated_on_field(field, operator, value)
    case operator
    when "!*"
      "#{Issue.table_name}.updated_on = #{Issue.table_name}.created_on"
    when "*"
      "#{Issue.table_name}.updated_on > #{Issue.table_name}.created_on"
    else
      sql_for_field("updated_on", operator, value, Issue.table_name, "updated_on")
    end
  end

  def sql_for_issue_id_field(field, operator, value)
    if operator == "="
      # accepts a comma separated list of ids
      ids = value.first.to_s.scan(/\d+/).map(&:to_i)
      if ids.present?
        "#{Issue.table_name}.id IN (#{ids.join(",")})"
      else
        "1=0"
      end
    else
      sql_for_field("id", operator, value, Issue.table_name, "id")
    end
  end

  def sql_for_relations(field, operator, value, options={})
    relation_options = IssueRelation::TYPES[field]
    return relation_options unless relation_options

    relation_type = field
    join_column, target_join_column = "issue_from_id", "issue_to_id"
    if relation_options[:reverse] || options[:reverse]
      relation_type = relation_options[:reverse] || relation_type
      join_column, target_join_column = target_join_column, join_column
    end
    sql =
      case operator
      when "*", "!*"
        op = (operator == "*" ? 'IN' : 'NOT IN')
        "#{Issue.table_name}.id #{op}" \
         " (SELECT DISTINCT #{IssueRelation.table_name}.#{join_column}" \
           " FROM #{IssueRelation.table_name}" \
             " WHERE #{IssueRelation.table_name}.relation_type =" \
                  " '#{self.class.connection.quote_string(relation_type)}')"
      when "=", "!"
        ids = value.first.to_s.scan(/\d+/).map(&:to_i).uniq
        if ids.present?
          op = (operator == "=" ? 'IN' : 'NOT IN')
          "#{Issue.table_name}.id #{op}" \
           " (SELECT DISTINCT #{IssueRelation.table_name}.#{join_column}" \
             " FROM #{IssueRelation.table_name}" \
               " WHERE #{IssueRelation.table_name}.relation_type =" \
                    " '#{self.class.connection.quote_string(relation_type)}'" \
                 " AND #{IssueRelation.table_name}.#{target_join_column} IN (#{ids.join(",")}))"
        else
          "1=0"
        end
      when "=p", "=!p", "!p"
        op = (operator == "!p" ? 'NOT IN' : 'IN')
        comp = (operator == "=!p" ? '<>' : '=')
        "#{Issue.table_name}.id #{op}" \
         " (SELECT DISTINCT #{IssueRelation.table_name}.#{join_column}" \
           " FROM #{IssueRelation.table_name}, #{Issue.table_name} relissues" \
             " WHERE #{IssueRelation.table_name}.relation_type =" \
                  " '#{self.class.connection.quote_string(relation_type)}'" \
             " AND #{IssueRelation.table_name}.#{target_join_column} = relissues.id" \
             " AND relissues.project_id #{comp} #{value.first.to_i})"
      when "*o", "!o"
        op = (operator == "!o" ? 'NOT IN' : 'IN')
        "#{Issue.table_name}.id #{op}" \
          " (SELECT DISTINCT #{IssueRelation.table_name}.#{join_column}" \
           " FROM #{IssueRelation.table_name}, #{Issue.table_name} relissues" \
             " WHERE #{IssueRelation.table_name}.relation_type =" \
                  " '#{self.class.connection.quote_string(relation_type)}'" \
             " AND #{IssueRelation.table_name}.#{target_join_column} = relissues.id" \
             " AND relissues.status_id IN" \
               " (SELECT id FROM #{IssueStatus.table_name}" \
               "  WHERE is_closed = #{self.class.connection.quoted_false}))"
      end
    if relation_options[:sym] == field && !options[:reverse]
      sqls = [sql, sql_for_relations(field, operator, value, :reverse => true)]
      sql = sqls.join(["!", "!*", "!p", '!o'].include?(operator) ? " AND " : " OR ")
    end
    "(#{sql})"
  end

  def sql_for_project_status_field(field, operator, value, options={})
    sql_for_field(field, operator, value, Project.table_name, "status")
  end

  def sql_for_any_searchable_field(field, operator, value)
    question = value.first

    # Fetch search results only from the selected and visible (sub-)projects
    project_scope = Project.allowed_to(:view_issues)
    if project
      projects = project_scope.where(project_statement)
    elsif has_filter?('project_id')
      case values_for('project_id').first
      when 'mine'
        project_ids = User.current.projects.ids
      when 'bookmarks'
        project_ids = User.current.bookmarked_project_ids
      else
        project_ids = values_for('project_id')
      end
      projects = project_scope.where(
        sql_for_field('project_id', operator_for('project_id'), project_ids, Project.table_name, 'id')
      )
    else
      projects = nil
    end

    is_all_words =
      case operator
      when '~'        then true
      when '*~', '!~' then false
      end

    is_open_issues = has_filter?('status_id') && operator_for('status_id') == 'o'

    fetcher = Redmine::Search::Fetcher.new(
      question, User.current, ['issue'], projects,
      all_words: is_all_words, open_issues: is_open_issues, attachments: '0'
    )
    ids = fetcher.result_ids.map(&:last)
    if ids.present?
      sw = operator == '!~' ? 'NOT' : ''
      "#{Issue.table_name}.id #{sw} IN (#{ids.join(',')})"
    else
      operator == '!~' ? '1=1' : '1=0'
    end
  end

  def find_assigned_to_id_filter_values(values)
    Principal.visible.where(:id => values).map {|p| [p.name, p.id.to_s]}
  end
  alias :find_author_id_filter_values :find_assigned_to_id_filter_values

  IssueRelation::TYPES.each_key do |relation_type|
    alias_method :"sql_for_#{relation_type}_field", :sql_for_relations
  end

  def joins_for_order_statement(order_options)
    joins = [super]

    if order_options
      if order_options.include?('authors')
        joins << "LEFT OUTER JOIN #{User.table_name} authors ON authors.id = #{queried_table_name}.author_id"
      end
      if order_options.include?('users')
        joins << "LEFT OUTER JOIN #{User.table_name} ON #{User.table_name}.id = #{queried_table_name}.assigned_to_id"
      end
      if order_options.include?('last_journal_user')
        joins <<
           "LEFT OUTER JOIN #{Journal.table_name}" \
             " ON #{Journal.table_name}.id = (SELECT MAX(#{Journal.table_name}.id)" \
             " FROM #{Journal.table_name}" \
             " WHERE #{Journal.table_name}.journalized_type = 'Issue'" \
             " AND #{Journal.table_name}.journalized_id = #{Issue.table_name}.id " \
             " AND #{Journal.visible_notes_condition(User.current, :skip_pre_condition => true)})" \
             " LEFT OUTER JOIN #{User.table_name} last_journal_user" \
             " ON last_journal_user.id = #{Journal.table_name}.user_id"
      end
      if order_options.include?('versions')
        joins <<
           "LEFT OUTER JOIN #{Version.table_name}" \
             " ON #{Version.table_name}.id = #{queried_table_name}.fixed_version_id"
      end
      if order_options.include?('issue_categories')
        joins <<
           "LEFT OUTER JOIN #{IssueCategory.table_name}" \
             " ON #{IssueCategory.table_name}.id = #{queried_table_name}.category_id"
      end
      if order_options.include?('trackers')
        joins <<
          "LEFT OUTER JOIN #{Tracker.table_name}" \
            " ON #{Tracker.table_name}.id = #{queried_table_name}.tracker_id"
      end
      if order_options.include?('enumerations')
        joins <<
          "LEFT OUTER JOIN #{IssuePriority.table_name}" \
            " ON #{IssuePriority.table_name}.id = #{queried_table_name}.priority_id"
      end
    end

    joins.any? ? joins.join(' ') : nil
  end
end
