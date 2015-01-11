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

class AutoCompletesController < ApplicationController
  before_filter :find_project

  def issues
    @issues = []
    q = (params[:q] || params[:term]).to_s.strip
    if q.present?
      scope = Issue.cross_project_scope(@project, params[:scope]).visible
      if q.match(/\A#?(\d+)\z/)
        @issues << scope.find_by_id($1.to_i)
      end
      @issues += scope.where("LOWER(#{Issue.table_name}.subject) LIKE LOWER(?)", "%#{q}%").order("#{Issue.table_name}.id DESC").limit(10).to_a
      @issues.compact!
    end
    render :layout => false
  end

  private

  def find_project
    if params[:project_id].present?
      @project = Project.find(params[:project_id])
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
