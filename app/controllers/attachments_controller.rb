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

class AttachmentsController < ApplicationController
  before_filter :find_attachment, :only => [:show, :download, :thumbnail, :destroy]
  before_filter :find_editable_attachments, :only => [:edit, :update]
  before_filter :file_readable, :read_authorize, :only => [:show, :download, :thumbnail]
  before_filter :delete_authorize, :only => :destroy
  before_filter :authorize_global, :only => :upload

  accept_api_auth :show, :download, :thumbnail, :upload, :destroy

  def show
    respond_to do |format|
      format.html {
        if @attachment.is_diff?
          @diff = File.read(@attachment.diskfile, :mode => "rb")
          @diff_type = params[:type] || User.current.pref[:diff_type] || 'inline'
          @diff_type = 'inline' unless %w(inline sbs).include?(@diff_type)
          # Save diff type as user preference
          if User.current.logged? && @diff_type != User.current.pref[:diff_type]
            User.current.pref[:diff_type] = @diff_type
            User.current.preference.save
          end
          render :action => 'diff'
        elsif @attachment.is_text? && @attachment.filesize <= Setting.file_max_size_displayed.to_i.kilobyte
          @content = File.read(@attachment.diskfile, :mode => "rb")
          render :action => 'file'
        elsif @attachment.is_image?
          render :action => 'image'
        else
          render :action => 'other'
        end
      }
      format.api
    end
  end

  def download
    if @attachment.container.is_a?(Version) || @attachment.container.is_a?(Project)
      @attachment.increment_download
    end

    if stale?(:etag => @attachment.digest)
      # images are sent inline
      send_file @attachment.diskfile, :filename => filename_for_content_disposition(@attachment.filename),
                                      :type => detect_content_type(@attachment),
                                      :disposition => disposition(@attachment)
    end
  end

  def thumbnail
    if @attachment.thumbnailable? && tbnail = @attachment.thumbnail(:size => params[:size])
      if stale?(:etag => tbnail)
        send_file tbnail,
          :filename => filename_for_content_disposition(@attachment.filename),
          :type => detect_content_type(@attachment),
          :disposition => 'inline'
      end
    else
      # No thumbnail for the attachment or thumbnail could not be created
      render :nothing => true, :status => 404
    end
  end

  def upload
    # Make sure that API users get used to set this content type
    # as it won't trigger Rails' automatic parsing of the request body for parameters
    unless request.content_type == 'application/octet-stream'
      render :nothing => true, :status => 406
      return
    end

    @attachment = Attachment.new(:file => request.raw_post)
    @attachment.author = User.current
    @attachment.filename = params[:filename].presence || Redmine::Utils.random_hex(16)
    @attachment.content_type = params[:content_type].presence
    saved = @attachment.save

    respond_to do |format|
      format.js
      format.api {
        if saved
          render :action => 'upload', :status => :created
        else
          render_validation_errors(@attachment)
        end
      }
    end
  end

  def edit
  end

  def update
    if params[:attachments].is_a?(Hash)
      if Attachment.update_attachments(@attachments, params[:attachments])
        redirect_back_or_default home_path
        return
      end
    end
    render :action => 'edit'
  end

  def destroy
    if @attachment.container.respond_to?(:init_journal)
      @attachment.container.init_journal(User.current)
    end
    if @attachment.container
      # Make sure association callbacks are called
      @attachment.container.attachments.delete(@attachment)
    else
      @attachment.destroy
    end

    respond_to do |format|
      format.html { redirect_to_referer_or project_path(@project) }
      format.js
      format.api { render_api_ok }
    end
  end

  private

  def find_attachment
    @attachment = Attachment.find(params[:id])
    # Show 404 if the filename in the url is wrong
    raise ActiveRecord::RecordNotFound if params[:filename] && params[:filename] != @attachment.filename
    @project = @attachment.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_editable_attachments
    klass = params[:object_type].to_s.singularize.classify.constantize rescue nil
    unless klass && klass.reflect_on_association(:attachments)
      render_404
      return
    end

    @container = klass.find(params[:object_id])
    if @container.respond_to?(:visible?) && !@container.visible?
      render_403
      return
    end
    @attachments = @container.attachments.select(&:editable?)
    if @container.respond_to?(:project)
      @project = @container.project
    end
    render_404 if @attachments.empty?
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Checks that the file exists and is readable
  def file_readable
    if @attachment.readable?
      true
    else
      logger.error "Cannot send attachment, #{@attachment.diskfile} does not exist or is unreadable."
      render_404
    end
  end

  def read_authorize
    @attachment.visible? ? true : deny_access
  end

  def delete_authorize
    @attachment.deletable? ? true : deny_access
  end

  def detect_content_type(attachment)
    content_type = attachment.content_type
    if content_type.blank? || content_type == "application/octet-stream"
      content_type = Redmine::MimeType.of(attachment.filename)
    end
    content_type.to_s
  end

  def disposition(attachment)
    if attachment.is_image? || attachment.is_pdf?
      'inline'
    else
      'attachment'
    end
  end
end
