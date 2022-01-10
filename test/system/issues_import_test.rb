# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

require File.expand_path('../../application_system_test_case', __FILE__)

class IssuesImportTest < ApplicationSystemTestCase
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :trackers, :projects_trackers, :enabled_modules, :issue_statuses, :issues,
           :enumerations, :custom_fields, :custom_values, :custom_fields_trackers,
           :watchers, :journals, :journal_details

  def test_import_issues_without_failures
    log_user('jsmith', 'jsmith')
    visit '/issues'
    find('div.contextual>span.drdn').click
    click_on 'Import'

    attach_file 'file', Rails.root.join('test/fixtures/files/import_issues.csv')
    click_on 'Next »'

    select 'Semicolon', :from => 'Field separator'
    select 'Double quote', :from => 'Field wrapper'
    select 'ISO-8859-1', :from => 'Encoding'
    select 'MM/DD/YYYY', :from => 'Date format'
    click_on 'Next »'

    select 'eCookbook', :from => 'Project'
    select 'tracker', :from => 'Tracker'
    select 'status', :from => 'Status'
    select 'subject', :from => 'Subject'

    assert_difference 'Issue.count', 3 do
      click_button 'Import'
      assert page.has_content?('3 items have been imported')
    end
  end
end
