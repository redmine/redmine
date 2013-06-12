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

require 'SVG/Graph/Bar'
require 'SVG/Graph/BarHorizontal'
require 'digest/sha1'
require 'redmine/scm/adapters/abstract_adapter'

class ChangesetNotFound < Exception; end
class InvalidRevisionParam < Exception; end

class RepositoriesController < ApplicationController
  menu_item :repository
  menu_item :settings, :only => [:new, :create, :edit, :update, :destroy, :committers]
  default_search_scope :changesets

  before_filter :find_project_by_project_id, :only => [:new, :create]
  before_filter :find_repository, :only => [:edit, :update, :destroy, :committers]
  before_filter :find_project_repository, :except => [:new, :create, :edit, :update, :destroy, :committers]
  before_filter :find_changeset, :only => [:revision, :add_related_issue, :remove_related_issue]
  before_filter :authorize
  accept_rss_auth :revisions

  rescue_from Redmine::Scm::Adapters::CommandFailed, :with => :show_error_command_failed

  def new
    scm = params[:repository_scm] || (Redmine::Scm::Base.all & Setting.enabled_scm).first
    @repository = Repository.factory(scm)
    @repository.is_default = @project.repository.nil?
    @repository.project = @project
  end

  def create
    attrs = pickup_extra_info
    @repository = Repository.factory(params[:repository_scm])
    @repository.safe_attributes = params[:repository]
    if attrs[:attrs_extra].keys.any?
      @repository.merge_extra_info(attrs[:attrs_extra])
    end
    @repository.project = @project
    if request.post? && @repository.save
      redirect_to settings_project_path(@project, :tab => 'repositories')
    else
      render :action => 'new'
    end
  end

  def edit
  end

  def update
    attrs = pickup_extra_info
    @repository.safe_attributes = attrs[:attrs]
    if attrs[:attrs_extra].keys.any?
      @repository.merge_extra_info(attrs[:attrs_extra])
    end
    @repository.project = @project
    if request.put? && @repository.save
      redirect_to settings_project_path(@project, :tab => 'repositories')
    else
      render :action => 'edit'
    end
  end

  def pickup_extra_info
    p       = {}
    p_extra = {}
    params[:repository].each do |k, v|
      if k =~ /^extra_/
        p_extra[k] = v
      else
        p[k] = v
      end
    end
    {:attrs => p, :attrs_extra => p_extra}
  end
  private :pickup_extra_info

  def committers
    @committers = @repository.committers
    @users = @project.users
    additional_user_ids = @committers.collect(&:last).collect(&:to_i) - @users.collect(&:id)
    @users += User.find_all_by_id(additional_user_ids) unless additional_user_ids.empty?
    @users.compact!
    @users.sort!
    if request.post? && params[:committers].is_a?(Hash)
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
      @entries ? render(:partial => 'dir_list_content') : render(:nothing => true)
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
      all

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

    @content = @repository.cat(@path, @rev)
    (show_error_not_found; return) unless @content
    if is_raw ||
         (@content.size && @content.size > Setting.file_max_size_displayed.to_i.kilobyte) ||
         ! is_entry_text_data?(@content, @path)
      # Force the download
      send_opt = { :filename => filename_for_content_disposition(@path.split('/').last) }
      send_type = Redmine::MimeType.of(@path)
      send_opt[:type] = send_type.to_s if send_type
      send_opt[:disposition] = (Redmine::MimeType.is_type?('image', @path) && !is_raw ? 'inline' : 'attachment')
      send_data @content, send_opt
    else
      # Prevent empty lines when displaying a file with Windows style eol
      # TODO: UTF-16
      # Is this needs? AttachmentsController reads file simply.
      @content.gsub!("\r\n", "\n")
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
    return false if ent.is_binary_data?
    true
  end
  private :is_entry_text_data?

  def annotate
    @entry = @repository.entry(@path, @rev)
    (show_error_not_found; return) unless @entry

    @annotate = @repository.scm.annotate(@path, @rev)
    if @annotate.nil? || @annotate.empty?
      (render_error l(:error_scm_annotate); return)
    end
    ann_buf_size = 0
    @annotate.lines.each do |buf|
      ann_buf_size += buf.size
    end
    if ann_buf_size > Setting.file_max_size_displayed.to_i.kilobyte
      (render_error l(:error_scm_annotate_big_text_file); return)
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
    @issue = @changeset.find_referenced_issue_by_id(params[:issue_id])
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
        show_error_not_found unless @diff
      end

      @changeset = @repository.find_changeset_by_name(@rev)
      @changeset_to = @rev_to ? @repository.find_changeset_by_name(@rev_to) : nil
      @diff_format_revisions = @repository.diff_format_revisions(@changeset, @changeset_to)
    end
  end

  def stats
  end

  def graph
    data = nil
    case params[:graph]
    when "commits_per_month"
      data = graph_commits_per_month(@repository)
    when "commits_per_author"
      data = graph_commits_per_author(@repository)
    end
    if data
      headers["Content-Type"] = "image/svg+xml"
      send_data(data, :type => "image/svg+xml", :disposition => "inline")
    else
      render_404
    end
  end

  private

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
    @date_to = Date.today
    @date_from = @date_to << 11
    @date_from = Date.civil(@date_from.year, @date_from.month, 1)
    commits_by_day = Changeset.
      where("repository_id = ? AND commit_date BETWEEN ? AND ?", repository.id, @date_from, @date_to).
      group(:commit_date).
      count
    commits_by_month = [0] * 12
    commits_by_day.each {|c| commits_by_month[(@date_to.month - c.first.to_date.month) % 12] += c.last }

    changes_by_day = Change.
      joins(:changeset).
      where("#{Changeset.table_name}.repository_id = ? AND #{Changeset.table_name}.commit_date BETWEEN ? AND ?", repository.id, @date_from, @date_to).
      group(:commit_date).
      count
    changes_by_month = [0] * 12
    changes_by_day.each {|c| changes_by_month[(@date_to.month - c.first.to_date.month) % 12] += c.last }

    fields = []
    12.times {|m| fields << month_name(((Date.today.month - 1 - m) % 12) + 1)}

    graph = SVG::Graph::Bar.new(
      :height => 300,
      :width => 800,
      :fields => fields.reverse,
      :stack => :side,
      :scale_integers => true,
      :step_x_labels => 2,
      :show_data_values => false,
      :graph_title => l(:label_commits_per_month),
      :show_graph_title => true
    )

    graph.add_data(
      :data => commits_by_month[0..11].reverse,
      :title => l(:label_revision_plural)
    )

    graph.add_data(
      :data => changes_by_month[0..11].reverse,
      :title => l(:label_change_plural)
    )

    graph.burn
  end

  def graph_commits_per_author(repository)
    commits_by_author = Changeset.where("repository_id = ?", repository.id).group(:committer).count
    commits_by_author.to_a.sort! {|x, y| x.last <=> y.last}

    changes_by_author = Change.joins(:changeset).where("#{Changeset.table_name}.repository_id = ?", repository.id).group(:committer).count
    h = changes_by_author.inject({}) {|o, i| o[i.first] = i.last; o}

    fields = commits_by_author.collect {|r| r.first}
    commits_data = commits_by_author.collect {|r| r.last}
    changes_data = commits_by_author.collect {|r| h[r.first] || 0}

    fields = fields + [""]*(10 - fields.length) if fields.length<10
    commits_data = commits_data + [0]*(10 - commits_data.length) if commits_data.length<10
    changes_data = changes_data + [0]*(10 - changes_data.length) if changes_data.length<10

    # Remove email adress in usernames
    fields = fields.collect {|c| c.gsub(%r{<.+@.+>}, '') }

    graph = SVG::Graph::BarHorizontal.new(
      :height => 30 * commits_data.length,
      :width => 800,
      :fields => fields,
      :stack => :side,
      :scale_integers => true,
      :show_data_values => false,
      :rotate_y_labels => false,
      :graph_title => l(:label_commits_per_author),
      :show_graph_title => true
    )
    graph.add_data(
      :data => commits_data,
      :title => l(:label_revision_plural)
    )
    graph.add_data(
      :data => changes_data,
      :title => l(:label_change_plural)
    )
    graph.burn
  end
end
