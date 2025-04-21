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

module RoutesHelper
  # Returns the path to project issues or to the cross-project
  # issue list if project is nil
  def _project_issues_path(project, *)
    if project
      project_issues_path(project, *)
    else
      issues_path(*)
    end
  end

  def _project_issues_url(project, *)
    if project
      project_issues_url(project, *)
    else
      issues_url(*)
    end
  end

  def _project_news_path(project, *)
    if project
      project_news_index_path(project, *)
    else
      news_index_path(*)
    end
  end

  def _new_project_issue_path(project, *)
    if project
      new_project_issue_path(project, *)
    else
      new_issue_path(*)
    end
  end

  def _project_calendar_path(project, *)
    project ? project_calendar_path(project, *) : issues_calendar_path(*)
  end

  def _project_gantt_path(project, *)
    project ? project_gantt_path(project, *) : issues_gantt_path(*)
  end

  def _time_entries_path(project, issue, *)
    if project
      project_time_entries_path(project, *)
    else
      time_entries_path(*)
    end
  end

  def _report_time_entries_path(project, issue, *)
    if project
      report_project_time_entries_path(project, *)
    else
      report_time_entries_path(*)
    end
  end

  def _new_time_entry_path(project, issue, *)
    if issue
      new_issue_time_entry_path(issue, *)
    elsif project
      new_project_time_entry_path(project, *)
    else
      new_time_entry_path(*)
    end
  end

  # Returns the path to bulk update issues or to issue path
  # if only one issue is selected for bulk update
  def _bulk_update_issues_path(issue, *)
    if issue
      issue_path(issue, *)
    else
      bulk_update_issues_path(*)
    end
  end

  def board_path(board, *)
    project_board_path(board.project, board, *)
  end
end
