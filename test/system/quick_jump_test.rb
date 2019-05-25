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

require File.expand_path('../../application_system_test_case', __FILE__)

class QuickJumpTest < ApplicationSystemTestCase
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :trackers, :projects_trackers, :enabled_modules, :issue_statuses, :issues,
           :enumerations, :custom_fields, :custom_values, :custom_fields_trackers,
           :watchers, :journals, :journal_details

  def test_project_quick_jump
    log_user 'jsmith', 'jsmith'
    visit '/'

    within '#header' do
      page.first('span', :text => 'Jump to a project...').click
      click_on 'eCookbook'
    end
    assert_current_path '/projects/ecookbook?jump=welcome'
  end

  def test_project_quick_jump_should_jump_to_the_same_tab
    log_user 'jsmith', 'jsmith'
    visit '/issues'

    within '#header' do
      page.first('span', :text => 'Jump to a project...').click
      click_on 'eCookbook'
      assert_current_path '/projects/ecookbook/issues'

      page.first('span', :text => 'eCookbook').click
      click_on 'All Projects'
      assert_current_path '/issues'
    end
  end

  def test_project_quick_search
    Project.generate!(:name => 'Megaproject', :identifier => 'mega')

    log_user 'jsmith', 'jsmith'
    visit '/'

    within '#header' do
      page.first('span', :text => 'Jump to a project...').click
      # Fill the quick search input that should have focus
      page.first('*:focus').set('meg')
      click_on 'Megaproject'
    end
    assert_current_path '/projects/mega?jump=welcome'
  end
end
