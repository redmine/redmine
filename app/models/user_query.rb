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

class UserQuery < Query
  self.layout = 'admin'
  self.queried_class = Principal # must be Principal (not User) for custom field filters to work

  self.available_columns = [
    QueryColumn.new(:login, sortable: "#{User.table_name}.login"),
    QueryColumn.new(:firstname, sortable: "#{User.table_name}.firstname"),
    QueryColumn.new(:lastname, sortable: "#{User.table_name}.lastname"),
    QueryColumn.new(:mail, sortable: "#{EmailAddress.table_name}.address"),
    QueryColumn.new(:admin, sortable: "#{User.table_name}.admin"),
    QueryColumn.new(:created_on, :sortable => "#{User.table_name}.created_on"),
    QueryColumn.new(:updated_on, :sortable => "#{User.table_name}.updated_on"),
    QueryColumn.new(:last_login_on, :sortable => "#{User.table_name}.last_login_on"),
    QueryColumn.new(:passwd_changed_on, :sortable => "#{User.table_name}.passwd_changed_on"),
    QueryColumn.new(:status, sortable: "#{User.table_name}.status"),
    QueryAssociationColumn.new(:auth_source, :name, caption: :field_auth_source, sortable: "#{AuthSource.table_name}.name")
  ]

  def self.visible(*args)
    user = args.shift || User.current
    if user.admin?
      where('1=1')
    else
      where('1=0')
    end
  end

  def initialize(attributes=nil, *args)
    super(attributes)
    self.filters ||= { 'status' => {operator: "=", values: [User::STATUS_ACTIVE]} }
  end

  def initialize_available_filters
    add_available_filter "status",
      type: :list_optional, values: ->{ user_statuses_values }
    add_available_filter "auth_source_id",
      type: :list_optional, values: ->{ auth_sources_values }
    add_available_filter "is_member_of_group",
      type: :list_optional,
      values: ->{ Group.givable.visible.pluck(:name, :id).map {|name, id| [name, id.to_s]} }
    if Setting.twofa?
      add_available_filter "twofa_scheme",
        type: :list_optional,
        values: ->{ Redmine::Twofa.available_schemes.map {|s| [I18n.t("twofa__#{s}__name"), s] } }
    end
    add_available_filter "name", type: :text, label: :field_name_or_email_or_login
    add_available_filter "login", type: :string
    add_available_filter "firstname", type: :string
    add_available_filter "lastname", type: :string
    add_available_filter "mail", type: :string
    add_available_filter "created_on", type: :date_past
    add_available_filter "last_login_on", type: :date_past
    add_available_filter "admin",
      type: :list,
      values: [[l(:general_text_yes), '1'], [l(:general_text_no), '0']]
    add_custom_fields_filters(user_custom_fields)
  end

  def visible?(user=User.current)
    user&.admin?
  end

  def editable_by?(user)
    user&.admin?
  end

  def auth_sources_values
    AuthSource.order(name: :asc).pluck(:name, :id)
  end

  def user_statuses_values
    [
      [l(:status_active), User::STATUS_ACTIVE.to_s],
      [l(:status_registered), User::STATUS_REGISTERED.to_s],
      [l(:status_locked), User::STATUS_LOCKED.to_s]
    ]
  end

  def available_columns
    return @available_columns if @available_columns

    @available_columns = self.class.available_columns.dup
    if Setting.twofa?
      @available_columns << QueryColumn.new(:twofa_scheme, sortable: "#{User.table_name}.twofa_scheme")
    end
    @available_columns += user_custom_fields.visible.
                            map {|cf| QueryCustomFieldColumn.new(cf)}

    @available_columns
  end

  # Returns a scope of user custom fields that are available as columns or filters
  def user_custom_fields
    UserCustomField.sorted
  end

  def default_columns_names
    @default_columns_names ||= [:login, :firstname, :lastname, :mail, :admin, :created_on, :last_login_on]
  end

  def default_sort_criteria
    [['login', 'asc']]
  end

  def base_scope
    User.logged.where(statement).includes(:email_address)
  end

  def results_scope(options={})
    order_option = [group_by_sort_order, (options[:order] || sort_clause)].flatten.reject(&:blank?)

    base_scope.
      order(order_option).
      joins(joins_for_order_statement(order_option.join(',')))
  end

  def sql_for_admin_field(field, operator, value)
    return unless value = value.first

    true_value = operator == '=' ? '1' : '0'
    val =
      if value.to_s == true_value
        self.class.connection.quoted_true
      else
        self.class.connection.quoted_false
      end
    "(#{User.table_name}.admin = #{val})"
  end

  def sql_for_is_member_of_group_field(field, operator, value)
    if ["*", "!*"].include? operator
      value = Group.givable.ids
    end

    e = operator.start_with?("!") ? "NOT EXISTS" : "EXISTS"

    "(#{e} (SELECT 1 FROM groups_users WHERE #{User.table_name}.id = groups_users.user_id AND #{sql_for_field(field, '=', value, 'groups_users', 'group_id')}))"
  end

  def sql_for_mail_field(field, operator, value)
    if operator == '!*'
      match = false
      operator = '*'
    else
      match = true
    end
    emails = EmailAddress.table_name
    <<-SQL
      #{match ? 'EXISTS' : 'NOT EXISTS'}
      (SELECT 1 FROM #{emails} WHERE
        #{emails}.user_id = #{User.table_name}.id AND
        #{sql_for_field(:mail, operator, value, emails, 'address')})
    SQL
  end

  def joins_for_order_statement(order_options)
    joins = [super]

    if order_options
      if order_options.include?('auth_source')
        joins << "LEFT OUTER JOIN #{AuthSource.table_name} auth_sources ON auth_sources.id = #{queried_table_name}.auth_source_id"
      end
    end

    joins.any? ? joins.join(' ') : nil
  end

  def sql_for_name_field(field, operator, value)
    case operator
    when '*'
      '1=1'
    when '!*'
      '1=0'
    else
      # match = (operator == '~')
      match = !operator.start_with?('!')
      matching_operator = operator.sub /^!/, ''
      name_sql = %w(login firstname lastname).map{|field| sql_for_field(:name, operator, value, User.table_name, field)}

      emails = EmailAddress.table_name
      email_sql = <<-SQL
        #{match ? "EXISTS" : "NOT EXISTS"}
        (SELECT 1 FROM #{emails} WHERE
          #{emails}.user_id = #{User.table_name}.id AND
          #{sql_for_field(:name, matching_operator, value, emails, 'address')})
      SQL

      conditions = name_sql + [email_sql]
      op = match ? " OR " : " AND "
      "(#{conditions.map{|s| "(#{s})"}.join(op)})"
    end
  end
end
