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

class VersionsTest < ApplicationSystemTestCase
  fixtures :projects, :trackers, :projects_trackers, :enabled_modules,
           :issue_statuses, :issues, :versions

  def test_index_with_blank_tracker_ids
    with_settings :default_language => 'en', :force_default_language_for_anonymous => '1' do
      visit '/projects/ecookbook/roadmap'

      find('#sidebar>form>ul:nth-child(3)>li:nth-child(1)>label>input[type=checkbox]').click
      find('#sidebar>form>ul:nth-child(3)>li:nth-child(2)>label>input[type=checkbox]').click
      find('#sidebar>form>ul:nth-child(3)>li:nth-child(3)>label>input[type=checkbox]').click
      click_on 'Apply'

      assert !page.has_css?('table.list.related-issues')
    end
  end
end
