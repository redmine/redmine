# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

module MyHelper
  def calendar_items(startdt, enddt)
    Issue.visible.
      where(:project_id => User.current.projects.map(&:id)).
      where("(start_date>=? and start_date<=?) or (due_date>=? and due_date<=?)", startdt, enddt, startdt, enddt).
      includes(:project, :tracker, :priority, :assigned_to).
      references(:project, :tracker, :priority, :assigned_to).
      to_a
  end

  def documents_items
    Document.visible.order("#{Document.table_name}.created_on DESC").limit(10).to_a
  end

  def issuesassignedtome_items
    Issue.visible.open.
      where(:assigned_to_id => ([User.current.id] + User.current.group_ids)).
      limit(10).
      includes(:status, :project, :tracker, :priority).
      references(:status, :project, :tracker, :priority).
      order("#{IssuePriority.table_name}.position DESC, #{Issue.table_name}.updated_on DESC").
      to_a
  end

  def issuesreportedbyme_items
    Issue.visible.
      where(:author_id => User.current.id).
      limit(10).
      includes(:status, :project, :tracker).
      references(:status, :project, :tracker).
      order("#{Issue.table_name}.updated_on DESC").
      to_a
  end

  def issueswatched_items
    Issue.visible.on_active_project.watched_by(User.current.id).recently_updated.limit(10).to_a
  end

  def news_items
    News.visible.
      where(:project_id => User.current.projects.map(&:id)).
      limit(10).
      includes(:project, :author).
      references(:project, :author).
      order("#{News.table_name}.created_on DESC").
      to_a
  end

  def timelog_items
    TimeEntry.
      where("#{TimeEntry.table_name}.user_id = ? AND #{TimeEntry.table_name}.spent_on BETWEEN ? AND ?", User.current.id, Date.today - 6, Date.today).
      joins(:activity, :project).
      references(:issue => [:tracker, :status]).
      includes(:issue => [:tracker, :status]).
      order("#{TimeEntry.table_name}.spent_on DESC, #{Project.table_name}.name ASC, #{Tracker.table_name}.position ASC, #{Issue.table_name}.id ASC").
      to_a
  end
end
