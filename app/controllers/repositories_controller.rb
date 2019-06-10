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

require 'digest/sha1'
require 'redmine/scm/adapters'

class ChangesetNotFound < Exception; end
class InvalidRevisionParam < Exception; end

class RepositoriesController < ApplicationController
  menu_item :repository
  menu_item :settings, :only => [:new, :create, :edit, :update, :destroy, :committers]
  default_search_scope :changesets

  before_action :find_project_by_project_id, :only => [:new, :create]
  before_action :build_new_repository_from_params, :only => [:new, :create]
  before_action :find_repository, :only => [:edit, :update, :destroy, :committers]
  before_action :find_project_repository, :except => [:new, :create, :edit, :update, :destroy, :committers]
  before_action :find_changeset, :only => [:revision, :add_related_issue, :remove_related_issue]
  before_action :authorize
  accept_rss_auth :revisions

  rescue_from Redmine::Scm::Adapters::CommandFailed, :with => :show_error_command_failed

  def new
    @repository.is_default = @project.repository.nil?
  end

  def create
    if @repository.save
      redirect_to settings_project_path(@project, :tab => 'repositories')
    else
      render :action => 'new'
    end
  end

  def edit
  end

  def update
    @repository.safe_attributes = params[:repository]
    if @repository.save
      redirect_to settings_project_path(@project, :tab => 'repositories')
    else
      render :action => 'edit'
    end
  end

  def committers
    @committers = @repository.committers
    @users = @project.users.to_a
    additional_user_ids = @committers.collect(&:last).collect(&:to_i) - @users.collect(&:id)
    @users += User.where(:id => additional_user_ids).to_a unless additional_user_ids.empty?
    @users.compact!
    @users.sort!
    if request.post? && params[:committers].present?
      # Build a hash with repository usernames as keys and corresponding user ids as values
      @repository.committer_ids = params[:committers].values.inject({}) {|h, c| h[c.first] = c.last; h}
      flash[:notice] = l(:notice_successful_update)
      redirect_to settings_project_path(@project, :tab => 'repositories')
    end
  end

  def destroy
    @repository.destroy if request.delete?
    redirect_to settings_project_path(@project, :tab => 'repositories')
  end

  def show
    @repository.fetch_changesets if @project.active? && Setting.autofetch_changesets? && @path.empty?

    @entries = @repository.entries(@path, @rev)
    @changeset = @repository.find_changeset_by_name(@rev)
    if request.xhr?
      @entries ? render(:partial => 'dir_list_content') : head(200)
    else
      (show_error_not_found; return) unless @entries
      @changesets = @repository.latest_changesets(@path, @rev)
      @properties = @repository.properties(@path, @rev)
      @repositories = @project.repositories
      render :action => 'show'
    end
  end

  alias_method :browse, :show

  def changes
    @entry = @repository.entry(@path, @rev)
    (show_error_not_found; return) unless @entry
    @changesets = @repository.latest_changesets(@path, @rev, Setting.repository_log_display_limit.to_i)
    @properties = @repository.properties(@path, @rev)
    @changeset = @repository.find_changeset_by_name(@rev)
  end

  def revisions
    @changeset_count = @repository.changesets.count
    @changeset_pages = Paginator.new @changeset_count,
                                     per_page_option,
                                     params['page']
    @changesets = @repository.changesets.
      limit(@changeset_pages.per_page).
      offset(@changeset_pages.offset).
      includes(:user, :repository, :parents).
      to_a

    respond_to do |format|
      format.html { render :layout => false if request.xhr? }
      format.atom { render_feed(@changesets, :title => "#{@project.name}: #{l(:label_revision_plural)}") }
    end
  end

  def raw
    entry_and_raw(true)
  end

  def entry
    entry_and_raw(false)
  end

  def entry_and_raw(is_raw)
    @entry = @repository.entry(@path, @rev)
    (show_error_not_found; return) unless @entry

    # If the entry is a dir, show the browser
    (show; return) if @entry.is_dir?

    if is_raw
      # Force the download
      send_opt = { :filename => filename_for_content_disposition(@path.split('/').last) }
      send_type = Redmine::MimeType.of(@path)
      send_opt[:type] = send_type.to_s if send_type
      send_opt[:disposition] = disposition(@path)
      send_data @repository.cat(@path, @rev), send_opt
    else
      # set up pagination from entry to entry
      parent_path = @path.split('/')[0...-1].join('/')
      @entries = @repository.entries(parent_path, @rev).reject(&:is_dir?)
      if index = @entries.index{|e| e.name == @entry.name}
        @paginator = Redmine::Pagination::Paginator.new(@entries.size, 1, index+1)
      end

      if !@entry.size || @entry.size <= Setting.file_max_size_displayed.to_i.kilobyte
        content = @repository.cat(@path, @rev)
        (show_error_not_found; return) unless content

        if content.size <= Setting.file_max_size_displayed.to_i.kilobyte &&
           is_entry_text_data?(content, @path)
          # TODO: UTF-16
          # Prevent empty lines when displaying a file with Windows style eol
          # Is this needed? AttachmentsController simply reads file.
          @content = content.gsub("\r\n", "\n")
        end
      end
      @changeset = @repository.find_changeset_by_name(@rev)
    end
  end
  private :entry_and_raw

  def is_entry_text_data?(ent, path)
    # UTF-16 contains "\x00".
    # It is very strict that file contains less than 30% of ascii symbols
    # in non Western Europe.
    return true if Redmine::MimeType.is_type?('text', path)
    # Ruby 1.8.6 has a bug of integer divisions.
    # http://apidock.com/ruby/v1_8_6_287/String/is_binary_data%3F
    return false if Redmine::Scm::Adapters::ScmData.binary?(ent)
    true
  end
  private :is_entry_text_data?

  def annotate
    @entry = @repository.entry(@path, @rev)
    (show_error_not_found; return) unless @entry

    @annotate = @repository.scm.annotate(@path, @rev)
    if @annotate.nil? || @annotate.empty?
      @annotate = nil
      @error_message = l(:error_scm_annotate)
    else
      ann_buf_size = 0
      @annotate.lines.each do |buf|
        ann_buf_size += buf.size
      end
      if ann_buf_size > Setting.file_max_size_displayed.to_i.kilobyte
        @annotate = nil
        @error_message = l(:error_scm_annotate_big_text_file)
      end
    end
    @changeset = @repository.find_changeset_by_name(@rev)
  end

  def revision
    respond_to do |format|
      format.html
      format.js {render :layout => false}
    end
  end

  # Adds a related issue to a changeset
  # POST /projects/:project_id/repository/(:repository_id/)revisions/:rev/issues
  def add_related_issue
    issue_id = params[:issue_id].to_s.sub(/^#/,'')
    @issue = @changeset.find_referenced_issue_by_id(issue_id)
    if @issue && (!@issue.visible? || @changeset.issues.include?(@issue))
      @issue = nil
    end

    if @issue
      @changeset.issues << @issue
    end
  end

  # Removes a related issue from a changeset
  # DELETE /projects/:project_id/repository/(:repository_id/)revisions/:rev/issues/:issue_id
  def remove_related_issue
    @issue = Issue.visible.find_by_id(params[:issue_id])
    if @issue
      @changeset.issues.delete(@issue)
    end
  end

  def diff
    if params[:format] == 'diff'
      @diff = @repository.diff(@path, @rev, @rev_to)
      (show_error_not_found; return) unless @diff
      filename = "changeset_r#{@rev}"
      filename << "_r#{@rev_to}" if @rev_to
      send_data @diff.join, :filename => "#{filename}.diff",
                            :type => 'text/x-patch',
                            :disposition => 'attachment'
    else
      @diff_type = params[:type] || User.current.pref[:diff_type] || 'inline'
      @diff_type = 'inline' unless %w(inline sbs).include?(@diff_type)

      # Save diff type as user preference
      if User.current.logged? && @diff_type != User.current.pref[:diff_type]
        User.current.pref[:diff_type] = @diff_type
        User.current.preference.save
      end
      @cache_key = "repositories/diff/#{@repository.id}/" +
                      Digest::MD5.hexdigest("#{@path}-#{@rev}-#{@rev_to}-#{@diff_type}-#{current_language}")
      unless read_fragment(@cache_key)
        @diff = @repository.diff(@path, @rev, @rev_to)
        (show_error_not_found; return) unless @diff
      end

      @changeset = @repository.find_changeset_by_name(@rev)
      @changeset_to = @rev_to ? @repository.find_changeset_by_name(@rev_to) : nil
      @diff_format_revisions = @repository.diff_format_revisions(@changeset, @changeset_to)
      render :diff, :formats => :html
    end
  end

  def stats
  end

  # Returns JSON data for repository graphs
  def graph
    data = nil
    case params[:graph]
    when "commits_per_month"
      data = graph_commits_per_month(@repository)
    when "commits_per_author"
      data = graph_commits_per_author(@repository)
    end
    if data
      render :json => data
    else
      render_404
    end
  end

  private

  def build_new_repository_from_params
    scm = params[:repository_scm] || (Redmine::Scm::Base.all & Setting.enabled_scm).first
    unless @repository = Repository.factory(scm)
      render_404
      return
    end

    @repository.project = @project
    @repository.safe_attributes = params[:repository]
    @repository
  end

  def find_repository
    @repository = Repository.find(params[:id])
    @project = @repository.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  REV_PARAM_RE = %r{\A[a-f0-9]*\Z}i

  def find_project_repository
    @project = Project.find(params[:id])
    if params[:repository_id].present?
      @repository = @project.repositories.find_by_identifier_param(params[:repository_id])
    else
      @repository = @project.repository
    end
    (render_404; return false) unless @repository
    @path = params[:path].is_a?(Array) ? params[:path].join('/') : params[:path].to_s
    @rev = params[:rev].blank? ? @repository.default_branch : params[:rev].to_s.strip
    @rev_to = params[:rev_to]

    unless @rev.to_s.match(REV_PARAM_RE) && @rev_to.to_s.match(REV_PARAM_RE)
      if @repository.branches.blank?
        raise InvalidRevisionParam
      end
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  rescue InvalidRevisionParam
    show_error_not_found
  end

  def find_changeset
    if @rev.present?
      @changeset = @repository.find_changeset_by_name(@rev)
    end
    show_error_not_found unless @changeset
  end

  def show_error_not_found
    render_error :message => l(:error_scm_not_found), :status => 404
  end

  # Handler for Redmine::Scm::Adapters::CommandFailed exception
  def show_error_command_failed(exception)
    render_error l(:error_scm_command_failed, exception.message)
  end

  def graph_commits_per_month(repository)
    date_to = User.current.today
    date_from = date_to << 11
    date_from = Date.civil(date_from.year, date_from.month, 1)
    commits_by_day = Changeset.
      where("repository_id = ? AND commit_date BETWEEN ? AND ?", repository.id, date_from, date_to).
      group(:commit_date).
      count
    commits_by_month = [0] * 12
    commits_by_day.each {|c| commits_by_month[(date_to.month - c.first.to_date.month) % 12] += c.last }

    changes_by_day = Change.
      joins(:changeset).
      where("#{Changeset.table_name}.repository_id = ? AND #{Changeset.table_name}.commit_date BETWEEN ? AND ?", repository.id, date_from, date_to).
      group(:commit_date).
      count
    changes_by_month = [0] * 12
    changes_by_day.each {|c| changes_by_month[(date_to.month - c.first.to_date.month) % 12] += c.last }

    fields = []
    today = User.current.today
    12.times {|m| fields << month_name(((today.month - 1 - m) % 12) + 1)}

    data = {
      :labels => fields.reverse,
      :commits => commits_by_month[0..11].reverse,
      :changes => changes_by_month[0..11].reverse
    }
  end

  def graph_commits_per_author(repository)
    #data
    stats = repository.stats_by_author
    fields, commits_data, changes_data = [], [], []
    stats.each do |name, hsh|
      fields << name
      commits_data << hsh[:commits_count]
      changes_data << hsh[:changes_count]
    end

    #expand to 10 values if needed
    fields = fields + [""]*(10 - fields.length) if fields.length<10
    commits_data = commits_data + [0]*(10 - commits_data.length) if commits_data.length<10
    changes_data = changes_data + [0]*(10 - changes_data.length) if changes_data.length<10

    # Remove email address in usernames
    fields = fields.collect {|c| c.gsub(%r{<.+@.+>}, '') }

    data = {
      :labels => fields.reverse,
      :commits => commits_data.reverse,
      :changes => changes_data.reverse
    }
  end

  def disposition(path)
    if Redmine::MimeType.of(@path) == "application/pdf"
      'inline'
    else
      'attachment'
    end
  end
end
