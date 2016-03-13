# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class Redmine::UiTest::TimelogTest < Redmine::UiTest::Base
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :trackers, :projects_trackers, :enabled_modules, :issue_statuses, :issues,
           :enumerations, :custom_fields, :custom_values, :custom_fields_trackers

  def test_changing_project_should_update_activities
    project = Project.find(1)
    TimeEntryActivity.create!(:name => 'Design', :project => project, :parent => TimeEntryActivity.find_by_name('Design'), :active => false)

    log_user 'jsmith', 'jsmith'
    visit '/time_entries/new'
    within 'select#time_entry_activity_id' do
      assert has_content?('Development')
      assert has_content?('Design')
    end

    within 'form#new_time_entry' do
      select 'eCookbook', :from => 'Project'
    end
    within 'select#time_entry_activity_id' do
      assert has_content?('Development')
      assert !has_content?('Design')
    end
  end
end
