# encoding: utf-8
#
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

module RoutesHelper

  # Returns the path to project issues or to the cross-project
  # issue list if project is nil
  def _project_issues_path(project, *args)
    if project
      project_issues_path(project, *args)
    else
      issues_path(*args)
    end
  end

  def _project_news_path(project, *args)
    if project
      project_news_index_path(project, *args)
    else
      news_index_path(*args)
    end
  end

  def _new_project_issue_path(project, *args)
    if project
      new_project_issue_path(project, *args)
    else
      new_issue_path(*args)
    end
  end

  def _project_calendar_path(project, *args)
    project ? project_calendar_path(project, *args) : issues_calendar_path(*args)
  end

  def _project_gantt_path(project, *args)
    project ? project_gantt_path(project, *args) : issues_gantt_path(*args)
  end

  def _time_entries_path(project, issue, *args)
    if project
      project_time_entries_path(project, *args)
    else
      time_entries_path(*args)
    end
  end

  def _report_time_entries_path(project, issue, *args)
    if project
      report_project_time_entries_path(project, *args)
    else
      report_time_entries_path(*args)
    end
  end

  def _new_time_entry_path(project, issue, *args)
    if issue
      new_issue_time_entry_path(issue, *args)
    elsif project
      new_project_time_entry_path(project, *args)
    else
      new_time_entry_path(*args)
    end
  end

  def board_path(board, *args)
    project_board_path(board.project, board, *args)
  end
end
