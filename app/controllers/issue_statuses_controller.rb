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

class IssueStatusesController < ApplicationController
  layout 'admin'

  before_filter :require_admin, :except => :index
  before_filter :require_admin_or_api_request, :only => :index
  accept_api_auth :index

  def index
    respond_to do |format|
      format.html {
        @issue_status_pages, @issue_statuses = paginate :issue_statuses, :per_page => 25, :order => "position"
        render :action => "index", :layout => false if request.xhr?
      }
      format.api {
        @issue_statuses = IssueStatus.all(:order => 'position')
      }
    end
  end

  def new
    @issue_status = IssueStatus.new
  end

  def create
    @issue_status = IssueStatus.new(params[:issue_status])
    if request.post? && @issue_status.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to :action => 'index'
    else
      render :action => 'new'
    end
  end

  def edit
    @issue_status = IssueStatus.find(params[:id])
  end

  def update
    @issue_status = IssueStatus.find(params[:id])
    if request.put? && @issue_status.update_attributes(params[:issue_status])
      flash[:notice] = l(:notice_successful_update)
      redirect_to :action => 'index'
    else
      render :action => 'edit'
    end
  end

  verify :method => :delete, :only => :destroy, :redirect_to => { :action => :index }
  def destroy
    IssueStatus.find(params[:id]).destroy
    redirect_to :action => 'index'
  rescue
    flash[:error] = l(:error_unable_delete_issue_status)
    redirect_to :action => 'index'
  end  	

  def update_issue_done_ratio
    if request.post? && IssueStatus.update_issue_done_ratios
      flash[:notice] = l(:notice_issue_done_ratios_updated)
    else
      flash[:error] =  l(:error_issue_done_ratios_not_updated)
    end
    redirect_to :action => 'index'
  end
end
