# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

class FilesController < ApplicationController
  menu_item :files

  before_action :find_project_by_project_id
  before_action :authorize
  accept_api_auth :index, :create

  helper :attachments
  helper :sort
  include SortHelper

  def index
    sort_init 'filename', 'asc'
    sort_update 'filename' => "#{Attachment.table_name}.filename",
                'created_on' => "#{Attachment.table_name}.created_on",
                'size' => "#{Attachment.table_name}.filesize",
                'downloads' => "#{Attachment.table_name}.downloads"

    @containers = [Project.includes(:attachments).
                     references(:attachments).reorder(sort_clause).find(@project.id)]
    @containers += @project.versions.includes(:attachments).
                    references(:attachments).reorder(sort_clause).to_a.sort.reverse
    respond_to do |format|
      format.html { render :layout => !request.xhr? }
      format.api
    end
  end

  def new
    @versions = @project.versions.sorted
  end

  def create
    version_id = params[:version_id] || (params[:file] && params[:file][:version_id])
    container = version_id.blank? ? @project : @project.versions.find_by_id(version_id)
    attachments = Attachment.attach_files(container, (params[:attachments] || (params[:file] && params[:file][:token] && params)))
    render_attachment_warning_if_needed(container)

    if attachments[:files].present?
      if Setting.notified_events.include?('file_added')
        Mailer.deliver_attachments_added(attachments[:files])
      end
      respond_to do |format|
        format.html {
          flash[:notice] = l(:label_file_added)
          redirect_to project_files_path(@project) }
        format.api { render_api_ok }
      end
    else
      respond_to do |format|
        format.html {
          flash.now[:error] = l(:label_attachment) + " " + l('activerecord.errors.messages.invalid')
          new
          render :action => 'new' }
        format.api { render :status => :bad_request }
      end
    end
  end
end
