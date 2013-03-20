# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

  def _project_calendar_path(project, *args)
    project ? project_calendar_path(project, *args) : issues_calendar_path(*args)
  end

  def _project_gantt_path(project, *args)
    project ? project_gantt_path(project, *args) : issues_gantt_path(*args)
  end
end
