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

class ProjectEnumerationsController < ApplicationController
  before_filter :find_project_by_project_id
  before_filter :authorize

  def update
    if params[:enumerations]
      saved = Project.transaction do
        params[:enumerations].each do |id, activity|
          @project.update_or_create_time_entry_activity(id, activity)
        end
      end
      if saved
        flash[:notice] = l(:notice_successful_update)
      end
    end

    redirect_to settings_project_path(@project, :tab => 'activities')
  end

  def destroy
    @project.time_entry_activities.each do |time_entry_activity|
      time_entry_activity.destroy(time_entry_activity.parent)
    end
    flash[:notice] = l(:notice_successful_update)
    redirect_to settings_project_path(@project, :tab => 'activities')
  end
end
