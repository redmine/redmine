# redMine - project management software
# Copyright (C) 2006-2007  Jean-Philippe Lang
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

class MailingListsController < ApplicationController
  layout 'base'
  
  before_filter :find_project, :authorize

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy ]
  
  def messages
    if params[:year] and params[:year].to_i > 1900
      @year = params[:year].to_i
      if params[:month] and params[:month].to_i > 0 and params[:month].to_i < 13
        @month = params[:month].to_i
      end    
    end
    @year ||= Date.today.year
    @month ||= Date.today.month    
    @date_from = Date.civil(@year, @month, 1)
    @date_to = (@date_from >> 1)-1
    
    @message_count = @mailing_list.messages.count(:conditions => ["sent_on>=? and sent_on<=?", @date_from, @date_to])
    @messages = @mailing_list.messages.find(:all, :conditions => ["parent_id is null and sent_on>=? and sent_on<=?", @date_from, @date_to])
    render :layout => false if request.xhr?
  end

  def add
    @mailing_list = MailingList.new(:project => @project, :admin => logged_in_user)
    @mailing_list.attributes = params[:mailing_list]
    if request.post? and @mailing_list.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to :controller => 'projects', :action => 'settings', :tab => 'mailing-lists', :id => @project
    end
  end

  def edit    
    if request.post? && @mailing_list.status == MailingList::STATUS_REQUESTED && @mailing_list.update_attributes(params[:mailing_list])
      flash[:notice] = l(:notice_successful_update)
      redirect_to :controller => 'projects', :action => 'settings', :tab => 'mailing-lists', :id => @project
    end
  end

  def destroy
    case @mailing_list.status
    when MailingList::STATUS_REQUESTED
      @mailing_list.destroy
    when MailingList::STATUS_CREATED
      @mailing_list.update_attribute :status, MailingList::STATUS_TO_BE_DELETED
    end
    redirect_to :controller => 'projects', :action => 'settings', :tab => 'mailing-lists', :id => @project
  end
  
private
  def find_project
    if params[:id]
      @mailing_list = MailingList.find(params[:id])
      @project = @mailing_list.project
    else
      @project = Project.find(params[:project_id])
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
