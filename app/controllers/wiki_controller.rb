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

# The WikiController follows the Rails REST controller pattern but with
# a few differences
#
# * index - shows a list of WikiPages grouped by page or date
# * new - not used
# * create - not used
# * show - will also show the form for creating a new wiki page
# * edit - used to edit an existing or new page
# * update - used to save a wiki page update to the database, including new pages
# * destroy - normal
#
# Other member and collection methods are also used
#
# TODO: still being worked on
class WikiController < ApplicationController
  default_search_scope :wiki_pages
  before_action :find_wiki, :authorize
  before_action :find_existing_or_new_page, :only => [:show, :edit]
  before_action :find_existing_page, :only => [:rename, :protect, :history, :diff, :annotate, :add_attachment, :destroy, :destroy_version]
  before_action :find_attachments, :only => [:preview]
  accept_api_auth :index, :show, :update, :destroy

  helper :attachments
  include AttachmentsHelper
  helper :watchers
  include Redmine::Export::PDF

  # List of pages, sorted alphabetically and by parent (hierarchy)
  def index
    load_pages_for_index

    respond_to do |format|
      format.html {
        @pages_by_parent_id = @pages.group_by(&:parent_id)
      }
      format.api
    end
  end

  # List of page, by last update
  def date_index
    load_pages_for_index
    @pages_by_date = @pages.group_by {|p| p.updated_on.to_date}
  end

  def new
    @page = WikiPage.new(:wiki => @wiki, :title => params[:title])
    unless User.current.allowed_to?(:edit_wiki_pages, @project)
      render_403
      return
    end
    if request.post?
      @page.title = '' unless editable?
      @page.validate
      if @page.errors[:title].blank?
        path = project_wiki_page_path(@project, @page.title, :parent => params[:parent])
        respond_to do |format|
          format.html { redirect_to path }
          format.js   { render :js => "window.location = #{path.to_json}" }
        end
      end
    end
  end

  # display a page (in editing mode if it doesn't exist)
  def show
    if params[:version] && !User.current.allowed_to?(:view_wiki_edits, @project)
      deny_access
      return
    end
    @content = @page.content_for_version(params[:version])
    if @content.nil?
      if User.current.allowed_to?(:edit_wiki_pages, @project) && editable? && !api_request?
        edit
        render :action => 'edit'
      else
        render_404
      end
      return
    end

    call_hook :controller_wiki_show_before_render, content: @content, format: params[:format]

    if User.current.allowed_to?(:export_wiki_pages, @project)
      if params[:format] == 'pdf'
        send_file_headers! :type => 'application/pdf', :filename => filename_for_content_disposition("#{@page.title}.pdf")
        return
      elsif params[:format] == 'html'
        export = render_to_string :action => 'export', :layout => false
        send_data(export, :type => 'text/html', :filename => filename_for_content_disposition("#{@page.title}.html"))
        return
      elsif params[:format] == 'txt'
        send_data(@content.text, :type => 'text/plain', :filename => filename_for_content_disposition("#{@page.title}.txt"))
        return
      end
    end
    @editable = editable?
    @sections_editable = @editable && User.current.allowed_to?(:edit_wiki_pages, @page.project) &&
      @content.current_version? &&
      Redmine::WikiFormatting.supports_section_edit?

    respond_to do |format|
      format.html
      format.api
    end
  end

  # edit an existing page or a new one
  def edit
    return render_403 unless editable?
    if @page.new_record?
      if params[:parent].present?
        @page.parent = @page.wiki.find_page(params[:parent].to_s)
      end
    end

    @content = @page.content_for_version(params[:version])
    @content ||= WikiContent.new(:page => @page)
    @content.text = initial_page_content(@page) if @content.text.blank?
    # don't keep previous comment
    @content.comments = nil

    # To prevent StaleObjectError exception when reverting to a previous version
    @content.version = @page.content.version if @page.content

    @text = @content.text
    if params[:section].present? && Redmine::WikiFormatting.supports_section_edit?
      @section = params[:section].to_i
      @text, @section_hash = Redmine::WikiFormatting.formatter.new(@text).get_section(@section)
      render_404 if @text.blank?
    end
  end

  # Creates a new page or updates an existing one
  def update
    @page = @wiki.find_or_new_page(params[:id])

    return render_403 unless editable?
    was_new_page = @page.new_record?
    @page.safe_attributes = params[:wiki_page]

    @content = @page.content || WikiContent.new(:page => @page)
    content_params = params[:content]
    if content_params.nil? && params[:wiki_page].present?
      content_params = params[:wiki_page].slice(:text, :comments, :version)
    end
    content_params ||= {}

    @content.comments = content_params[:comments]
    @text = content_params[:text]
    if params[:section].present? && Redmine::WikiFormatting.supports_section_edit?
      @section = params[:section].to_i
      @section_hash = params[:section_hash]
      @content.text = Redmine::WikiFormatting.formatter.new(@content.text).update_section(@section, @text, @section_hash)
    else
      @content.version = content_params[:version] if content_params[:version]
      @content.text = @text
    end
    @content.author = User.current

    if @page.save_with_content(@content)
      attachments = Attachment.attach_files(@page, params[:attachments] || (params[:wiki_page] && params[:wiki_page][:uploads]))
      render_attachment_warning_if_needed(@page)
      call_hook(:controller_wiki_edit_after_save, { :params => params, :page => @page})

      respond_to do |format|
        format.html {
          anchor = @section ? "section-#{@section}" : nil
          redirect_to project_wiki_page_path(@project, @page.title, :anchor => anchor)
        }
        format.api {
          if was_new_page
            render :action => 'show', :status => :created, :location => project_wiki_page_path(@project, @page.title)
          else
            render_api_ok
          end
        }
      end
    else
      respond_to do |format|
        format.html { render :action => 'edit' }
        format.api { render_validation_errors(@content) }
      end
    end

  rescue ActiveRecord::StaleObjectError, Redmine::WikiFormatting::StaleSectionError
    # Optimistic locking exception
    respond_to do |format|
      format.html {
        flash.now[:error] = l(:notice_locking_conflict)
        render :action => 'edit'
      }
      format.api { render_api_head :conflict }
    end
  end

  # rename a page
  def rename
    return render_403 unless editable?
    @page.redirect_existing_links = true
    # used to display the *original* title if some AR validation errors occur
    @original_title = @page.pretty_title
    @page.safe_attributes = params[:wiki_page]
    if request.post? && @page.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to project_wiki_page_path(@page.project, @page.title)
    end
  end

  def protect
    @page.update_attribute :protected, params[:protected]
    redirect_to project_wiki_page_path(@project, @page.title)
  end

  # show page history
  def history
    @version_count = @page.content.versions.count
    @version_pages = Paginator.new @version_count, per_page_option, params['page']
    # don't load text
    @versions = @page.content.versions.
      select("id, author_id, comments, updated_on, version").
      reorder('version DESC').
      limit(@version_pages.per_page + 1).
      offset(@version_pages.offset).
      to_a

    render :layout => false if request.xhr?
  end

  def diff
    @diff = @page.diff(params[:version], params[:version_from])
    render_404 unless @diff
  end

  def annotate
    @annotate = @page.annotate(params[:version])
    render_404 unless @annotate
  end

  # Removes a wiki page and its history
  # Children can be either set as root pages, removed or reassigned to another parent page
  def destroy
    return render_403 unless editable?

    @descendants_count = @page.descendants.size
    if @descendants_count > 0
      case params[:todo]
      when 'nullify'
        # Nothing to do
      when 'destroy'
        # Removes all its descendants
        @page.descendants.each(&:destroy)
      when 'reassign'
        # Reassign children to another parent page
        reassign_to = @wiki.pages.find_by_id(params[:reassign_to_id].to_i)
        return unless reassign_to
        @page.children.each do |child|
          child.update_attribute(:parent, reassign_to)
        end
      else
        @reassignable_to = @wiki.pages - @page.self_and_descendants
        # display the destroy form if it's a user request
        return unless api_request?
      end
    end
    @page.destroy
    respond_to do |format|
      format.html { redirect_to project_wiki_index_path(@project) }
      format.api { render_api_ok }
    end
  end

  def destroy_version
    return render_403 unless editable?

    if content = @page.content.versions.find_by_version(params[:version])
      content.destroy
      redirect_to_referer_or history_project_wiki_page_path(@project, @page.title)
    else
      render_404
    end
  end

  # Export wiki to a single pdf or html file
  def export
    @pages = @wiki.pages.
                      order('title').
                      includes([:content, {:attachments => :author}]).
                      to_a
    respond_to do |format|
      format.html {
        export = render_to_string :action => 'export_multiple', :layout => false
        send_data(export, :type => 'text/html', :filename => "wiki.html")
      }
      format.pdf {
        send_file_headers! :type => 'application/pdf', :filename => "#{@project.identifier}.pdf"
      }
    end
  end

  def preview
    page = @wiki.find_page(params[:id])
    # page is nil when previewing a new page
    return render_403 unless page.nil? || editable?(page)
    if page
      @attachments += page.attachments
      @previewed = page.content
    end
    @text = params[:content].present? ? params[:content][:text] : params[:text]
    render :partial => 'common/preview'
  end

  def add_attachment
    return render_403 unless editable?
    attachments = Attachment.attach_files(@page, params[:attachments])
    render_attachment_warning_if_needed(@page)
    redirect_to :action => 'show', :id => @page.title, :project_id => @project
  end

  private

  def find_wiki
    @project = Project.find(params[:project_id])
    @wiki = @project.wiki
    render_404 unless @wiki
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Finds the requested page or a new page if it doesn't exist
  def find_existing_or_new_page
    @page = @wiki.find_or_new_page(params[:id])
    if @wiki.page_found_with_redirect?
      redirect_to_page @page
    end
  end

  # Finds the requested page and returns a 404 error if it doesn't exist
  def find_existing_page
    @page = @wiki.find_page(params[:id])
    if @page.nil?
      render_404
      return
    end
    if @wiki.page_found_with_redirect?
      redirect_to_page @page
    end
  end

  def redirect_to_page(page)
    if page.project && page.project.visible?
      redirect_to :action => action_name, :project_id => page.project, :id => page.title
    else
      render_404
    end
  end

  # Returns true if the current user is allowed to edit the page, otherwise false
  def editable?(page = @page)
    page.editable_by?(User.current)
  end

  # Returns the default content of a new wiki page
  def initial_page_content(page)
    helper = Redmine::WikiFormatting.helper_for(Setting.text_formatting)
    extend helper unless self.instance_of?(helper)
    helper.instance_method(:initial_page_content).bind(self).call(page)
  end

  def load_pages_for_index
    @pages = @wiki.pages.with_updated_on.
                reorder("#{WikiPage.table_name}.title").
                includes(:wiki => :project).
                includes(:parent).
                to_a
  end
end
