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

require_relative '../../../../../test_helper'

class IssuesPdfHelperTest < ActiveSupport::TestCase
  include Redmine::Export::PDF::IssuesPdfHelper

  def test_fetch_row_values_should_round_float_values
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.column_names = [:subject, :spent_hours]
    issue = Issue.find(2)
    user = User.find(1)
    time_entry = TimeEntry.create!(:spent_on => Date.today, :hours => 4.3432, :user => user, :author => user,
                     :project_id => 1, :issue => issue, :activity => TimeEntryActivity.first)

    to_test = {'en' => '4.34', 'de' => '4,34'}
    to_test.each do |locale, expected|
      with_locale locale do
        results = fetch_row_values(issue, query, 0)
        assert_equal ['2', 'Add ingredients categories', expected], results
      end
    end
  end

  def test_fetch_row_values_should_be_able_to_handle_parent_issue_subject
    query = IssueQuery.new(:project => Project.find(1), :name => '_')
    query.column_names = [:subject, 'parent.subject']
    issue = Issue.find(2)
    issue.parent = Issue.find(1)
    issue.save!

    results = fetch_row_values(issue, query, 0)
    assert_equal ['2', 'Add ingredients categories', 'Cannot print recipes'], results
  end
end
