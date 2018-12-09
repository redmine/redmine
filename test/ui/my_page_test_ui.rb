# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

require File.expand_path('../base', __FILE__)

class Redmine::UiTest::MyPageTest < Redmine::UiTest::Base
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :trackers, :projects_trackers, :enabled_modules, :issue_statuses, :issues,
           :enumerations, :custom_fields, :custom_values, :custom_fields_trackers,
           :watchers, :journals, :journal_details

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
end
