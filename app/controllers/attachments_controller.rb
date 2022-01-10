# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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
  include ActionView::Helpers::NumberHelper

  before_action :find_attachment, :only => [:show, :download, :thumbnail, :update, :destroy]
  before_action :find_container, :only => [:edit_all, :update_all, :download_all]
  before_action :find_downloadable_attachments, :only => :download_all
  before_action :find_editable_attachments, :only => [:edit_all, :update_all]
  before_action :file_readable, :read_authorize, :only => [:show, :download, :thumbnail]
  before_action :update_authorize, :only => :update
  before_action :delete_authorize, :only => :destroy
  before_action :authorize_global, :only => :upload

  # Disable check for same origin requests for JS files, i.e. attachments with
  # MIME type text/javascript.
  skip_after_action :verify_same_origin_request, :only => :download

  accept_api_auth :show, :download, :thumbnail, :upload, :update, :destroy

  def show
    respond_to do |format|
      format.html do
        if @attachment.container.respond_to?(:attachments)
          @attachments = @attachment.container.attachments.to_a
          if index = @attachments.index(@attachment)
            @paginator = Redmine::Pagination::Paginator.new(
              @attachments.size, 1, index+1
            )
          end
        end
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
      end
      format.api
    end
  end

  def download
    if @attachment.container.is_a?(Version) || @attachment.container.is_a?(Project)
      @attachment.increment_download
    end

    if stale?(:etag => @attachment.digest, :template => false)
      # images are sent inline
      send_file @attachment.diskfile, :filename => filename_for_content_disposition(@attachment.filename),
                                      :type => detect_content_type(@attachment),
                                      :disposition => disposition(@attachment)
    end
  end

  def thumbnail
    if @attachment.thumbnailable? && tbnail = @attachment.thumbnail(:size => params[:size])
      if stale?(:etag => tbnail, :template => false)
        send_file(
          tbnail,
          :filename => filename_for_content_disposition(@attachment.filename),
          :type => detect_content_type(@attachment, true),
          :disposition => 'inline')
      end
    else
      # No thumbnail for the attachment or thumbnail could not be created
      head 404
    end
  end

  def upload
    # Make sure that API users get used to set this content type
    # as it won't trigger Rails' automatic parsing of the request body for parameters
    unless request.content_type == 'application/octet-stream'
      head 406
      return
    end

    @attachment = Attachment.new(:file => raw_request_body)
    @attachment.author = User.current
    @attachment.filename = params[:filename].presence || Redmine::Utils.random_hex(16)
    @attachment.content_type = params[:content_type].presence
    saved = @attachment.save

    respond_to do |format|
      format.js
      format.api do
        if saved
          render :action => 'upload', :status => :created
        else
          render_validation_errors(@attachment)
        end
      end
    end
  end

  # Edit all the attachments of a container
  def edit_all
  end

  # Update all the attachments of a container
  def update_all
    if Attachment.update_attachments(@attachments, update_all_params)
      redirect_back_or_default home_path
      return
    end
    render :action => 'edit_all'
  end

  def download_all
    zip_data = Attachment.archive_attachments(@attachments)
    if zip_data
      file_name = "#{@container.class.to_s.downcase}-#{@container.id}-attachments.zip"
      send_data(
        zip_data,
        :type => Redmine::MimeType.of(file_name),
        :filename => file_name
      )
    else
      render_404
    end
  end

  def update
    @attachment.safe_attributes = params[:attachment]
    saved = @attachment.save

    respond_to do |format|
      format.api do
        if saved
          render_api_ok
        else
          render_validation_errors(@attachment)
        end
      end
    end
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
      format.html {redirect_to_referer_or project_path(@project)}
      format.js
      format.api {render_api_ok}
    end
  end

  # Returns the menu item that should be selected when viewing an attachment
  def current_menu_item
    container = @attachment.try(:container) || @container

    if container
      case container
      when WikiPage
        :wiki
      when Message
        :boards
      when Project, Version
        :files
      else
        container.class.name.pluralize.downcase.to_sym
      end
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
    @attachments = @container.attachments.select(&:editable?)
    render_404 if @attachments.empty?
  end

  def find_container
    klass =
      begin
        params[:object_type].to_s.singularize.classify.constantize
      rescue
        nil
      end
    unless klass && (klass.reflect_on_association(:attachments) || klass.method_defined?(:attachments))
      render_404
      return
    end

    @container = klass.find(params[:object_id])
    if @container.respond_to?(:visible?) && !@container.visible?
      render_403
      return
    end
    if @container.respond_to?(:project)
      @project = @container.project
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_downloadable_attachments
    @attachments = @container.attachments.select(&:readable?)
    bulk_download_max_size = Setting.bulk_download_max_size.to_i.kilobytes
    if @attachments.sum(&:filesize) > bulk_download_max_size
      flash[:error] = l(:error_bulk_download_size_too_big,
                        :max_size => number_to_human_size(bulk_download_max_size.to_i))
      redirect_to back_url
      return
    end
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

  def update_authorize
    @attachment.editable? ? true : deny_access
  end

  def delete_authorize
    @attachment.deletable? ? true : deny_access
  end

  def detect_content_type(attachment, is_thumb = false)
    content_type = attachment.content_type
    if content_type.blank? || content_type == "application/octet-stream"
      content_type =
        Redmine::MimeType.of(attachment.filename).presence ||
        "application/octet-stream"
    end

    if is_thumb && content_type == "application/pdf"
      # PDF previews are stored in PNG format
      content_type = "image/png"
    end

    content_type
  end

  def disposition(attachment)
    if attachment.is_pdf?
      'inline'
    else
      'attachment'
    end
  end

  # Returns attachments param for #update_all
  def update_all_params
    params.permit(:attachments => [:filename, :description]).require(:attachments)
  end

  # Get an IO-like object for the request body which is usable to create a new
  # attachment. We try to avoid having to read the whole body into memory.
  def raw_request_body
    if request.body.respond_to?(:size)
      request.body
    else
      request.raw_post
    end
  end
end
