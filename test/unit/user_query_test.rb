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

require_relative '../test_helper'

class UserQueryTest < ActiveSupport::TestCase
  def test_available_columns_should_include_user_custom_fields
    query = UserQuery.new
    assert_include :cf_4, query.available_columns.map(&:name)
  end

  def test_filter_values_should_be_arrays
    q = UserQuery.new

    q.available_filters.each do |name, filter|
      values = filter.values
      assert (values.nil? || values.is_a?(Array)),
        "#values for #{name} filter returned a #{values.class.name}"
    end
  end

  def test_filter_by_admin
    q = UserQuery.new name: '_'
    q.filters = { 'admin' => { operator: '=', values: ['1'] }}
    users = find_users_with_query q
    assert_equal [true], users.map(&:admin?).uniq

    q.filters = { 'admin' => { operator: '!', values: ['1'] }}
    users = find_users_with_query q
    assert_equal [false], users.map(&:admin?).uniq

    q.filters = { 'admin' => { operator: '!', values: ['0'] }}
    users = find_users_with_query q
    assert_equal [true], users.map(&:admin?).uniq

    q.filters = { 'admin' => { operator: '!', values: ['1'] }}
    users = find_users_with_query q
    assert_equal [false], users.map(&:admin?).uniq
  end

  def test_filter_by_status
    q = UserQuery.new name: '_'
    q.filters = { 'status' => { operator: '=', values: [User::STATUS_LOCKED] }}
    users = find_users_with_query q
    assert_equal [5], users.map(&:id)
  end

  def test_login_filter
    [
      ['~', 'jsmith', [2]],
      ['^', 'jsm', [2]],
      ['$', 'ith', [2]],
    ].each do |op, string, result|
      q = UserQuery.new name: '_'
      q.add_filter('login', op, [string])
      users = find_users_with_query q
      assert_equal result, users.map(&:id), "#{op} #{string} should have found #{result}"
    end
  end

  def test_firstname_filter
    q = UserQuery.new name: '_'
    q.add_filter('firstname', '~', ['john'])
    users = find_users_with_query q
    assert_equal [2], users.map(&:id)
  end

  def test_lastname_filter
    q = UserQuery.new name: '_'
    q.add_filter('lastname', '~', ['smith'])
    users = find_users_with_query q
    assert_equal [2], users.map(&:id)
  end

  def test_mail_filter
    [
      ['~', 'somenet', [1, 2, 3, 4]],
      ['!~', 'somenet', [7, 8, 9]],
      ['^', 'dlop', [3]],
      ['$', 'bar', [7, 8, 9]],
      ['=', 'bar', []],
      ['=', 'someone@foo.bar', [7]],
      ['*', '', [1, 2, 3, 4, 7, 8, 9]],
      ['!*', '', []],
    ].each do |op, string, result|
      q = UserQuery.new name: '_'
      q.add_filter('mail', op, [string])
      users = find_users_with_query q
      assert_equal result, users.map(&:id).sort, "#{op} #{string} should have found #{result}"
    end
  end

  def test_name_or_email_or_login_filter
    [
      ['~', 'jsmith', [2]],
      ['^', 'jsm', [2]],
      ['$', 'ith', [2]],
      ['~', 'john', [2]],
      ['~', 'smith', [2]],
      ['~', 'somenet', [1, 2, 3, 4]],
      ['!~', 'somenet', [7, 8, 9]],
      ['^', 'dlop', [3]],
      ['$', 'bar', [7, 8, 9]],
      ['=', 'bar', []],
      ['=', 'someone@foo.bar', [7]],
      ['*', '', [1, 2, 3, 4, 7, 8, 9]],
      ['!*', '', []],
    ].each do |op, string, result|
      q = UserQuery.new name: '_'
      q.add_filter('name', op, [string])
      users = find_users_with_query q
      assert_equal result, users.map(&:id).sort, "#{op} #{string} should have found #{result}"
    end
  end

  def test_group_filter
    q = UserQuery.new name: '_'
    q.add_filter('is_member_of_group', '=', ['10', '99'])
    users = find_users_with_query q
    assert_equal [8], users.map(&:id)
  end

  def test_group_filter_not
    q = UserQuery.new name: '_'
    q.add_filter('is_member_of_group', '!', ['10'])
    users = find_users_with_query q
    assert users.any?
    assert_not users.map(&:id).include? 8
  end

  def test_group_filter_any
    q = UserQuery.new name: '_'
    q.add_filter('is_member_of_group', '*', [''])
    users = find_users_with_query q
    assert_equal [8], users.map(&:id)
  end

  def test_group_filter_none
    q = UserQuery.new name: '_'
    q.add_filter('is_member_of_group', '!*', [''])
    users = find_users_with_query q
    assert users.any?
    assert_not users.map(&:id).include? 8
  end

  def test_auth_source_filter
    user = User.find(1)
    user.update_column :auth_source_id, 1

    q = UserQuery.new name: '_'
    q.add_filter('auth_source_id', '=', ['1'])
    users = find_users_with_query q
    assert_equal [1], users.map(&:id)
  end

  def test_auth_source_filter_any
    user = User.find(1)
    user.update_column :auth_source_id, 1

    q = UserQuery.new name: '_'
    q.add_filter('auth_source_id', '*', [''])
    users = find_users_with_query q
    assert_equal [1], users.map(&:id)
  end

  def test_auth_source_filter_none
    user = User.find(1)
    user.update_column :auth_source_id, 1

    q = UserQuery.new name: '_'
    q.add_filter('auth_source_id', '!*', [''])
    users = find_users_with_query q
    assert users.any?
    assert_not users.map(&:id).include? 1
  end

  def test_auth_source_ordering
    auth = AuthSource.generate!(name: "Auth")

    user = User.find(1)
    user.update_column :auth_source_id, 1

    user2 = User.find(2)
    user2.update_column :auth_source_id, auth.id

    q = UserQuery.new name: '_'
    q.add_filter('auth_source_id', '*', [''])
    q.column_names = ['id', 'auth_source.name']
    q.sort_criteria = [['auth_source.name', 'asc']]

    users = q.results_scope

    assert_equal 2, users.size
    assert_equal [2, 1], users.pluck(:id)
  end

  def test_user_query_is_only_visible_to_admins
    q = UserQuery.new(name: '_')
    assert q.save

    admin = User.admin(true).first
    user = User.admin(false).first

    assert q.visible?(admin)
    assert_include q, UserQuery.visible(admin).to_a

    assert_not q.visible?(user)
    assert_not_include q, UserQuery.visible(user)
  end

  def test_user_query_is_only_editable_by_admins
    q = UserQuery.new(name: '_')

    admin = User.admin(true).first
    user = User.admin(false).first

    assert q.editable_by?(admin)
    assert_not q.editable_by?(user)
  end

  def find_users_with_query(query)
    User.where(query.statement).to_a
  end
end
