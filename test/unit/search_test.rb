# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class SearchTest < ActiveSupport::TestCase
  fixtures :users,
           :members,
           :member_roles,
           :projects,
           :projects_trackers,
           :roles,
           :enabled_modules,
           :issues,
           :trackers,
           :issue_statuses,
           :enumerations,
           :journals,
           :journal_details,
           :repositories,
           :changesets

  def setup
    User.current = nil
    @project = Project.find(1)
    @issue_keyword = '%unable to print recipes%'
    @issue = Issue.find(1)
    @changeset_keyword = '%very first commit%'
    @changeset = Changeset.find(100)
  end

  def test_search_by_anonymous
    User.current = nil

    r = Issue.search_results(@issue_keyword)
    assert r.include?(@issue)
    r = Changeset.search_results(@changeset_keyword)
    assert r.include?(@changeset)

    # Removes the :view_changesets permission from Anonymous role
    remove_permission Role.anonymous, :view_changesets
    User.current = nil

    r = Issue.search_results(@issue_keyword)
    assert r.include?(@issue)
    r = Changeset.search_results(@changeset_keyword)
    assert !r.include?(@changeset)

    # Make the project private
    @project.update_attribute :is_public, false
    r = Issue.search_results(@issue_keyword)
    assert !r.include?(@issue)
    r = Changeset.search_results(@changeset_keyword)
    assert !r.include?(@changeset)
  end

  def test_search_by_user
    User.current = User.find_by_login('rhill')
    assert User.current.memberships.empty?

    r = Issue.search_results(@issue_keyword)
    assert r.include?(@issue)
    r = Changeset.search_results(@changeset_keyword)
    assert r.include?(@changeset)

    # Removes the :view_changesets permission from Non member role
    remove_permission Role.non_member, :view_changesets
    User.current = User.find_by_login('rhill')

    r = Issue.search_results(@issue_keyword)
    assert r.include?(@issue)
    r = Changeset.search_results(@changeset_keyword)
    assert !r.include?(@changeset)

    # Make the project private
    @project.update_attribute :is_public, false
    r = Issue.search_results(@issue_keyword)
    assert !r.include?(@issue)
    r = Changeset.search_results(@changeset_keyword)
    assert !r.include?(@changeset)
  end

  def test_search_by_allowed_member
    User.current = User.find_by_login('jsmith')
    assert User.current.projects.include?(@project)

    r = Issue.search_results(@issue_keyword)
    assert r.include?(@issue)
    r = Changeset.search_results(@changeset_keyword)
    assert r.include?(@changeset)

    # Make the project private
    @project.update_attribute :is_public, false
    r = Issue.search_results(@issue_keyword)
    assert r.include?(@issue)
    r = Changeset.search_results(@changeset_keyword)
    assert r.include?(@changeset)
  end

  def test_search_by_unallowed_member
    # Removes the :view_changesets permission from user's and non member role
    remove_permission Role.find(1), :view_changesets
    remove_permission Role.non_member, :view_changesets

    User.current = User.find_by_login('jsmith')
    assert User.current.projects.include?(@project)

    r = Issue.search_results(@issue_keyword)
    assert r.include?(@issue)
    r = Changeset.search_results(@changeset_keyword)
    assert !r.include?(@changeset)

    # Make the project private
    @project.update_attribute :is_public, false
    r = Issue.search_results(@issue_keyword)
    assert r.include?(@issue)
    r = Changeset.search_results(@changeset_keyword)
    assert !r.include?(@changeset)
  end

  def test_search_issue_with_multiple_hits_in_journals
    issue = Issue.find(1)
    assert_equal 2, issue.journals.where("notes LIKE '%notes%'").count

    r = Issue.search_results('%notes%')
    assert_equal 1, r.size
    assert_equal issue, r.first
  end

  def test_search_should_be_case_insensitive
    issue = Issue.generate!(:subject => "AzerTY")

    r = Issue.search_results('AZERty')
    assert_include issue, r
  end

  def test_search_should_be_case_insensitive_with_accented_characters
    unless sqlite?
      issue1 = Issue.generate!(:subject => "Special chars: ÖÖ")
      issue2 = Issue.generate!(:subject => "Special chars: Öö")
      r = Issue.search_results('ÖÖ')
      assert_include issue1, r
      assert_include issue2, r
    end
  end

  def test_search_should_be_case_and_accent_insensitive_with_mysql
    if mysql?
      issue1 = Issue.generate!(:subject => "OO")
      issue2 = Issue.generate!(:subject => "oo")
      r = Issue.search_results('ÖÖ')
      assert_include issue1, r
      assert_include issue2, r
    end
  end

  def test_search_should_be_case_and_accent_insensitive_with_postgresql_and_noaccent_extension
    if postgresql?
      skip unless Redmine::Database.postgresql_version >= 90000
      # Extension will be rollbacked with the test transaction
      ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS unaccent")
      Redmine::Database.reset
      assert Redmine::Database.postgresql_unaccent?
      issue1 = Issue.generate!(:subject => "OO")
      issue2 = Issue.generate!(:subject => "oo")
      r = Issue.search_results('ÖÖ')
      assert_include issue1, r
      assert_include issue2, r
    end
  ensure
    Redmine::Database.reset
  end

  def test_fetcher_should_handle_accents_in_phrases
    f = Redmine::Search::Fetcher.new('No special chars "in a phrase"', User.anonymous, %w(issues), Project.all)
    assert_equal ['No', 'special', 'chars', 'in a phrase'], f.tokens

    f = Redmine::Search::Fetcher.new('Special chars "in a phrase Öö"', User.anonymous, %w(issues), Project.all)
    assert_equal ['Special', 'chars', 'in a phrase Öö'], f.tokens
  end

  def test_fetcher_should_exclude_single_character_tokens_except_for_chinese_characters
    f = Redmine::Search::Fetcher.new('ca f é 漢 あ 한', User.anonymous, %w(issues), Project.all)
    assert_equal ['ca', '漢'], f.tokens
  end

  private

  def remove_permission(role, permission)
    role.permissions = role.permissions - [ permission ]
    role.save
  end
end
