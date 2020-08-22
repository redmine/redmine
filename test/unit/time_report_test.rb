# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2020  Jean-Philippe Lang
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

class TimeReportTest < ActiveSupport::TestCase
  fixtures :trackers, :users

  def setup
    User.current = nil
  end

  def report_by(criteria)
    project = nil
    issue = nil # Unused argument. TODO: Remove
    Redmine::Helpers::TimeReport.new(project, issue, criteria, 'month', TimeEntry.all)
  end

  def test_project_sorted_by_name
    project_b = Project.generate!(name: 'Project B')
    project_a = Project.generate!(name: 'Project A')
    TimeEntry.generate!(project: project_b)
    TimeEntry.generate!(project: project_a)
    report = report_by(['project'])

    result_projects = report.hours.map { |row| row['project']  }

    assert_equal result_projects, [project_a.id, project_b.id]
  end
end
