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

class IssueRelationsController < ApplicationController
  before_filter :find_issue, :find_project_from_association, :authorize, :only => [:index, :create]
  before_filter :find_relation, :except => [:index, :create]

  accept_api_auth :index, :show, :create, :destroy

  def index
    @relations = @issue.relations

    respond_to do |format|
      format.html { render :nothing => true }
      format.api
    end
  end

  def show
    raise Unauthorized unless @relation.visible?

    respond_to do |format|
      format.html { render :nothing => true }
      format.api
    end
  end

  def create
    @relation = IssueRelation.new(params[:relation])
    @relation.issue_from = @issue
    if params[:relation] && m = params[:relation][:issue_to_id].to_s.strip.match(/^#?(\d+)$/)
      @relation.issue_to = Issue.visible.find_by_id(m[1].to_i)
    end
    saved = @relation.save

    respond_to do |format|
      format.html { redirect_to issue_path(@issue) }
      format.js {
        @relations = @issue.reload.relations.select {|r| r.other_issue(@issue) && r.other_issue(@issue).visible? }
      }
      format.api {
        if saved
          render :action => 'show', :status => :created, :location => relation_url(@relation)
        else
          render_validation_errors(@relation)
        end
      }
    end
  end

  def destroy
    raise Unauthorized unless @relation.deletable?
    @relation.destroy

    respond_to do |format|
      format.html { redirect_to issue_path(@relation.issue_from) }
      format.js
      format.api  { render_api_ok }
    end
  end

private
  def find_issue
    @issue = @object = Issue.find(params[:issue_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_relation
    @relation = IssueRelation.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
