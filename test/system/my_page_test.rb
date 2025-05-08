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

require_relative '../application_system_test_case'

class MyPageTest < ApplicationSystemTestCase
  def test_sort_assigned_issues
    preferences = User.find(2).pref
    preferences.my_page_layout = {'top' => ['issuesassignedtome']}
    preferences.my_page_settings = {'issuesassignedtome' => {:columns => ['tracker', 'subject', 'due_date'], :sort => 'id:desc'}}
    preferences.save!

    log_user('jsmith', 'jsmith')
    visit '/my/page'
    assert page.has_css?('table.issues.sort-by-id')
    assert page.has_css?('table.issues.sort-desc')

    within('#block-issuesassignedtome') do
      # sort by tracker asc
      click_link 'Tracker'
      assert page.has_css?('table.issues.sort-by-tracker')
      assert page.has_css?('table.issues.sort-asc')

      # and desc
      click_link 'Tracker'
      assert page.has_css?('table.issues.sort-by-tracker')
      assert page.has_css?('table.issues.sort-desc')
    end

    # reload the page, sort order should be preserved
    visit '/my/page'
    assert page.has_css?('table.issues.sort-by-tracker')
    assert page.has_css?('table.issues.sort-desc')
  end

  def test_add_block
    preferences = User.find(2).pref
    preferences.my_page_layout = {'top' => ['issuesassignedtome']}
    preferences.save!

    log_user('jsmith', 'jsmith')
    visit '/my/page'
    select 'Watched issues', :from => 'Add'

    assert page.has_css?('#block-issueswatched')
    assert_equal({'top' => ['issueswatched', 'issuesassignedtome']},
                 preferences.reload.my_page_layout)
  end

  def test_add_issue_query_block
    preferences = User.find(2).pref
    preferences.my_page_layout = {'top' => ['issuesassignedtome']}
    preferences.save!
    query = IssueQuery.create!(:name => 'My query', :user_id => 2)

    log_user('jsmith', 'jsmith')
    visit '/my/page'
    select 'Issues', :from => 'Add'
    # Select which query to display
    select query.name, :from => 'Custom query'
    click_on 'Save'

    assert page.has_css?('#block-issuequery table.issues')
    assert_equal({'top' => ['issuequery', 'issuesassignedtome']}, preferences.reload.my_page_layout)
    assert_equal({:query_id => query.id.to_s}, preferences.my_page_settings['issuequery'])
  end

  def test_remove_block
    preferences = User.find(2).pref
    preferences.my_page_layout = {'top' => ['issuesassignedtome']}
    preferences.save!

    log_user('jsmith', 'jsmith')
    visit '/my/page'
    within '#block-issuesassignedtome' do
      click_on 'Delete'
    end
    assert page.has_no_css?('#block-issuesassignedtome')
    assert_equal({'top' => []}, preferences.reload.my_page_layout)
  end
end
