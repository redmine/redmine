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

class AutoCompletesController < ApplicationController
  before_action :find_project

  def issues
    issues = []
    q = (params[:q] || params[:term]).to_s.strip
    status = params[:status].to_s
    issue_id = params[:issue_id].to_s

    scope = Issue.cross_project_scope(@project, params[:scope]).visible
    scope = scope.open(status == 'o') if status.present?
    scope = scope.where.not(:id => issue_id.to_i) if issue_id.present?
    if q.present?
      if q =~ /\A#?(\d+)\z/
        issues << scope.find_by(:id => $1.to_i)
      end
      issues += scope.like(q).order(:id => :desc).limit(10).to_a
      issues.compact!
    else
      issues += scope.order(:id => :desc).limit(10).to_a
    end

    render :json => format_issues_json(issues)
  end

  private

  def find_project
    if params[:project_id].present?
      @project = Project.find(params[:project_id])
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def format_issues_json(issues)
    issues.map {|issue|
      {
        'id' => issue.id,
        'label' => "#{issue.tracker} ##{issue.id}: #{issue.subject.to_s.truncate(60)}",
        'value' => issue.id
      }
    }
  end
end
