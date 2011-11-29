# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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

  verify :method => :post, :only => :create, :render => {:nothing => true, :status => :method_not_allowed }
  def create
    @relation = IssueRelation.new(params[:relation])
    @relation.issue_from = @issue
    if params[:relation] && m = params[:relation][:issue_to_id].to_s.match(/^#?(\d+)$/)
      @relation.issue_to = Issue.visible.find_by_id(m[1].to_i)
    end
    saved = @relation.save

    respond_to do |format|
      format.html { redirect_to :controller => 'issues', :action => 'show', :id => @issue }
      format.js do
        @relations = @issue.relations.select {|r| r.other_issue(@issue) && r.other_issue(@issue).visible? }
        render :update do |page|
          page.replace_html "relations", :partial => 'issues/relations'
          if @relation.errors.empty?
            page << "$('relation_delay').value = ''"
            page << "$('relation_issue_to_id').value = ''"
          end
        end
      end
      format.api {
        if saved
          render :action => 'show', :status => :created, :location => relation_url(@relation)
        else
          render_validation_errors(@relation)
        end
      }
    end
  end

  verify :method => :delete, :only => :destroy, :render => {:nothing => true, :status => :method_not_allowed }
  def destroy
    raise Unauthorized unless @relation.deletable?
    @relation.destroy

    respond_to do |format|
      format.html { redirect_to :controller => 'issues', :action => 'show', :id => @issue }
      format.js   { render(:update) {|page| page.remove "relation-#{@relation.id}"} }
      format.api  { head :ok }
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
