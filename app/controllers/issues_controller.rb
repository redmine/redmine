# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

class IssuesController < ApplicationController
  menu_item :new_issue, :only => [:new, :create]
  default_search_scope :issues

  before_filter :find_issue, :only => [:show, :edit, :update]
  before_filter :find_issues, :only => [:bulk_edit, :bulk_update, :destroy]
  before_filter :authorize, :except => [:index, :new, :create]
  before_filter :find_optional_project, :only => [:index, :new, :create]
  before_filter :build_new_issue_from_params, :only => [:new, :create]
  accept_rss_auth :index, :show
  accept_api_auth :index, :show, :create, :update, :destroy

  rescue_from Query::StatementInvalid, :with => :query_statement_invalid

  helper :journals
  helper :projects
  helper :custom_fields
  helper :issue_relations
  helper :watchers
  helper :attachments
  helper :queries
  include QueriesHelper
  helper :repositories
  helper :sort
  include SortHelper
  helper :timelog

  def index
    retrieve_query
    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a

    if @query.valid?
      case params[:format]
      when 'csv', 'pdf'
        @limit = Setting.issues_export_limit.to_i
        if params[:columns] == 'all'
          @query.column_names = @query.available_inline_columns.map(&:name)
        end
      when 'atom'
        @limit = Setting.feeds_limit.to_i
      when 'xml', 'json'
        @offset, @limit = api_offset_and_limit
        @query.column_names = %w(author)
      else
        @limit = per_page_option
      end

      @issue_count = @query.issue_count
      @issue_pages = Paginator.new @issue_count, @limit, params['page']
      @offset ||= @issue_pages.offset
      @issues = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
                              :order => sort_clause,
                              :offset => @offset,
                              :limit => @limit)
      @issue_count_by_group = @query.issue_count_by_group

      respond_to do |format|
        format.html { render :template => 'issues/index', :layout => !request.xhr? }
        format.api  {
          Issue.load_visible_relations(@issues) if include_in_api_response?('relations')
        }
        format.atom { render_feed(@issues, :title => "#{@project || Setting.app_title}: #{l(:label_issue_plural)}") }
        format.csv  { send_data(query_to_csv(@issues, @query, params), :type => 'text/csv; header=present', :filename => 'issues.csv') }
        format.pdf  { send_file_headers! :type => 'application/pdf', :filename => 'issues.pdf' }
      end
    else
      respond_to do |format|
        format.html { render(:template => 'issues/index', :layout => !request.xhr?) }
        format.any(:atom, :csv, :pdf) { render(:nothing => true) }
        format.api { render_validation_errors(@query) }
      end
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def show
    @journals = @issue.journals.includes(:user, :details).
                    references(:user, :details).
                    reorder(:created_on, :id).to_a
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reject!(&:private_notes?) unless User.current.allowed_to?(:view_private_notes, @issue.project)
    Journal.preload_journals_details_custom_fields(@journals)
    @journals.select! {|journal| journal.notes? || journal.visible_details.any?}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?

    @changesets = @issue.changesets.visible.preload(:repository, :user).to_a
    @changesets.reverse! if User.current.wants_comments_in_reverse_order?

    @relations = @issue.relations.select {|r| r.other_issue(@issue) && r.other_issue(@issue).visible? }
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
    @priorities = IssuePriority.active
    @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
    @relation = IssueRelation.new

    respond_to do |format|
      format.html {
        retrieve_previous_and_next_issue_ids
        render :template => 'issues/show'
      }
      format.api
      format.atom { render :template => 'journals/index', :layout => false, :content_type => 'application/atom+xml' }
      format.pdf  {
        send_file_headers! :type => 'application/pdf', :filename => "#{@project.identifier}-#{@issue.id}.pdf"
      }
    end
  end

  def new
    respond_to do |format|
      format.html { render :action => 'new', :layout => !request.xhr? }
      format.js
    end
  end

  def create
    unless User.current.allowed_to?(:add_issues, @issue.project, :global => true)
      raise ::Unauthorized
    end
    call_hook(:controller_issues_new_before_save, { :params => params, :issue => @issue })
    @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
    if @issue.save
      call_hook(:controller_issues_new_after_save, { :params => params, :issue => @issue})
      respond_to do |format|
        format.html {
          render_attachment_warning_if_needed(@issue)
          flash[:notice] = l(:notice_issue_successful_create, :id => view_context.link_to("##{@issue.id}", issue_path(@issue), :title => @issue.subject))
          redirect_after_create
        }
        format.api  { render :action => 'show', :status => :created, :location => issue_url(@issue) }
      end
      return
    else
      respond_to do |format|
        format.html {
          if @issue.project.nil?
            render_error :status => 422
          else
            render :action => 'new'
          end
        }
        format.api  { render_validation_errors(@issue) }
      end
    end
  end

  def edit
    return unless update_issue_from_params

    respond_to do |format|
      format.html { }
      format.js
    end
  end

  def update
    return unless update_issue_from_params
    @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
    saved = false
    begin
      saved = save_issue_with_child_records
    rescue ActiveRecord::StaleObjectError
      @conflict = true
      if params[:last_journal_id]
        @conflict_journals = @issue.journals_after(params[:last_journal_id]).to_a
        @conflict_journals.reject!(&:private_notes?) unless User.current.allowed_to?(:view_private_notes, @issue.project)
      end
    end

    if saved
      render_attachment_warning_if_needed(@issue)
      flash[:notice] = l(:notice_successful_update) unless @issue.current_journal.new_record?

      respond_to do |format|
        format.html { redirect_back_or_default issue_path(@issue) }
        format.api  { render_api_ok }
      end
    else
      respond_to do |format|
        format.html { render :action => 'edit' }
        format.api  { render_validation_errors(@issue) }
      end
    end
  end

  # Bulk edit/copy a set of issues
  def bulk_edit
    @issues.sort!
    @copy = params[:copy].present?
    @notes = params[:notes]

    if @copy
      unless User.current.allowed_to?(:copy_issues, @projects)
        raise ::Unauthorized
      end
    end

    @allowed_projects = Issue.allowed_target_projects
    if params[:issue]
      @target_project = @allowed_projects.detect {|p| p.id.to_s == params[:issue][:project_id].to_s}
      if @target_project
        target_projects = [@target_project]
      end
    end
    target_projects ||= @projects

    if @copy
      # Copied issues will get their default statuses
      @available_statuses = []
    else
      @available_statuses = @issues.map(&:new_statuses_allowed_to).reduce(:&)
    end
    @custom_fields = @issues.map{|i|i.editable_custom_fields}.reduce(:&)
    @assignables = target_projects.map(&:assignable_users).reduce(:&)
    @trackers = target_projects.map(&:trackers).reduce(:&)
    @versions = target_projects.map {|p| p.shared_versions.open}.reduce(:&)
    @categories = target_projects.map {|p| p.issue_categories}.reduce(:&)
    if @copy
      @attachments_present = @issues.detect {|i| i.attachments.any?}.present?
      @subtasks_present = @issues.detect {|i| !i.leaf?}.present?
    end

    @safe_attributes = @issues.map(&:safe_attribute_names).reduce(:&)

    @issue_params = params[:issue] || {}
    @issue_params[:custom_field_values] ||= {}
  end

  def bulk_update
    @issues.sort!
    @copy = params[:copy].present?

    attributes = parse_params_for_bulk_issue_attributes(params)
    copy_subtasks = (params[:copy_subtasks] == '1')
    copy_attachments = (params[:copy_attachments] == '1')

    if @copy
      unless User.current.allowed_to?(:copy_issues, @projects)
        raise ::Unauthorized
      end
      target_projects = @projects
      if attributes['project_id'].present?
        target_projects = Project.where(:id => attributes['project_id']).to_a
      end
      unless User.current.allowed_to?(:add_issues, target_projects)
        raise ::Unauthorized
      end
    end

    unsaved_issues = []
    saved_issues = []

    if @copy && copy_subtasks
      # Descendant issues will be copied with the parent task
      # Don't copy them twice
      @issues.reject! {|issue| @issues.detect {|other| issue.is_descendant_of?(other)}}
    end

    @issues.each do |orig_issue|
      orig_issue.reload
      if @copy
        issue = orig_issue.copy({},
          :attachments => copy_attachments,
          :subtasks => copy_subtasks,
          :link => link_copy?(params[:link_copy])
        )
      else
        issue = orig_issue
      end
      journal = issue.init_journal(User.current, params[:notes])
      issue.safe_attributes = attributes
      call_hook(:controller_issues_bulk_edit_before_save, { :params => params, :issue => issue })
      if issue.save
        saved_issues << issue
      else
        unsaved_issues << orig_issue
      end
    end

    if unsaved_issues.empty?
      flash[:notice] = l(:notice_successful_update) unless saved_issues.empty?
      if params[:follow]
        if @issues.size == 1 && saved_issues.size == 1
          redirect_to issue_path(saved_issues.first)
        elsif saved_issues.map(&:project).uniq.size == 1
          redirect_to project_issues_path(saved_issues.map(&:project).first)
        end
      else
        redirect_back_or_default _project_issues_path(@project)
      end
    else
      @saved_issues = @issues
      @unsaved_issues = unsaved_issues
      @issues = Issue.visible.where(:id => @unsaved_issues.map(&:id)).to_a
      bulk_edit
      render :action => 'bulk_edit'
    end
  end

  def destroy
    @hours = TimeEntry.where(:issue_id => @issues.map(&:id)).sum(:hours).to_f
    if @hours > 0
      case params[:todo]
      when 'destroy'
        # nothing to do
      when 'nullify'
        TimeEntry.where(['issue_id IN (?)', @issues]).update_all('issue_id = NULL')
      when 'reassign'
        reassign_to = @project.issues.find_by_id(params[:reassign_to_id])
        if reassign_to.nil?
          flash.now[:error] = l(:error_issue_not_found_in_project)
          return
        else
          TimeEntry.where(['issue_id IN (?)', @issues]).
            update_all("issue_id = #{reassign_to.id}")
        end
      else
        # display the destroy form if it's a user request
        return unless api_request?
      end
    end
    @issues.each do |issue|
      begin
        issue.reload.destroy
      rescue ::ActiveRecord::RecordNotFound # raised by #reload if issue no longer exists
        # nothing to do, issue was already deleted (eg. by a parent)
      end
    end
    respond_to do |format|
      format.html { redirect_back_or_default _project_issues_path(@project) }
      format.api  { render_api_ok }
    end
  end

  private

  def retrieve_previous_and_next_issue_ids
    retrieve_query_from_session
    if @query
      sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
      sort_update(@query.sortable_columns, 'issues_index_sort')
      limit = 500
      issue_ids = @query.issue_ids(:order => sort_clause, :limit => (limit + 1), :include => [:assigned_to, :tracker, :priority, :category, :fixed_version])
      if (idx = issue_ids.index(@issue.id)) && idx < limit
        if issue_ids.size < 500
          @issue_position = idx + 1
          @issue_count = issue_ids.size
        end
        @prev_issue_id = issue_ids[idx - 1] if idx > 0
        @next_issue_id = issue_ids[idx + 1] if idx < (issue_ids.size - 1)
      end
    end
  end

  # Used by #edit and #update to set some common instance variables
  # from the params
  def update_issue_from_params
    @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
    if params[:time_entry]
      @time_entry.attributes = params[:time_entry]
    end

    @issue.init_journal(User.current)

    issue_attributes = params[:issue]
    if issue_attributes && params[:conflict_resolution]
      case params[:conflict_resolution]
      when 'overwrite'
        issue_attributes = issue_attributes.dup
        issue_attributes.delete(:lock_version)
      when 'add_notes'
        issue_attributes = issue_attributes.slice(:notes)
      when 'cancel'
        redirect_to issue_path(@issue)
        return false
      end
    end
    @issue.safe_attributes = issue_attributes
    @priorities = IssuePriority.active
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
    true
  end

  # Used by #new and #create to build a new issue from the params
  # The new issue will be copied from an existing one if copy_from parameter is given
  def build_new_issue_from_params
    @issue = Issue.new
    if params[:copy_from]
      begin
        @issue.init_journal(User.current)
        @copy_from = Issue.visible.find(params[:copy_from])
        unless User.current.allowed_to?(:copy_issues, @copy_from.project)
          raise ::Unauthorized
        end
        @link_copy = link_copy?(params[:link_copy]) || request.get?
        @copy_attachments = params[:copy_attachments].present? || request.get?
        @copy_subtasks = params[:copy_subtasks].present? || request.get?
        @issue.copy_from(@copy_from, :attachments => @copy_attachments, :subtasks => @copy_subtasks, :link => @link_copy)
      rescue ActiveRecord::RecordNotFound
        render_404
        return
      end
    end
    @issue.project = @project
    if request.get?
      @issue.project ||= @issue.allowed_target_projects.first
    end
    @issue.author ||= User.current
    @issue.start_date ||= Date.today if Setting.default_issue_start_date_to_creation_date?

    if attrs = params[:issue].deep_dup
      if action_name == 'new' && params[:was_default_status] == attrs[:status_id]
        attrs.delete(:status_id)
      end
      @issue.safe_attributes = attrs
    end
    if @issue.project
      @issue.tracker ||= @issue.project.trackers.first
      if @issue.tracker.nil?
        render_error l(:error_no_tracker_in_project)
        return false
      end
      if @issue.status.nil?
        render_error l(:error_no_default_issue_status)
        return false
      end
    end

    @priorities = IssuePriority.active
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current, @issue.new_record?)
  end

  def parse_params_for_bulk_issue_attributes(params)
    attributes = (params[:issue] || {}).reject {|k,v| v.blank?}
    attributes.keys.each {|k| attributes[k] = '' if attributes[k] == 'none'}
    if custom = attributes[:custom_field_values]
      custom.reject! {|k,v| v.blank?}
      custom.keys.each do |k|
        if custom[k].is_a?(Array)
          custom[k] << '' if custom[k].delete('__none__')
        else
          custom[k] = '' if custom[k] == '__none__'
        end
      end
    end
    attributes
  end

  # Saves @issue and a time_entry from the parameters
  def save_issue_with_child_records
    Issue.transaction do
      if params[:time_entry] && (params[:time_entry][:hours].present? || params[:time_entry][:comments].present?) && User.current.allowed_to?(:log_time, @issue.project)
        time_entry = @time_entry || TimeEntry.new
        time_entry.project = @issue.project
        time_entry.issue = @issue
        time_entry.user = User.current
        time_entry.spent_on = User.current.today
        time_entry.attributes = params[:time_entry]
        @issue.time_entries << time_entry
      end

      call_hook(:controller_issues_edit_before_save, { :params => params, :issue => @issue, :time_entry => time_entry, :journal => @issue.current_journal})
      if @issue.save
        call_hook(:controller_issues_edit_after_save, { :params => params, :issue => @issue, :time_entry => time_entry, :journal => @issue.current_journal})
      else
        raise ActiveRecord::Rollback
      end
    end
  end

  # Returns true if the issue copy should be linked
  # to the original issue
  def link_copy?(param)
    case Setting.link_copied_issue
    when 'yes'
      true
    when 'no'
      false
    when 'ask'
      param == '1'
    end
  end

  # Redirects user after a successful issue creation
  def redirect_after_create
    if params[:continue]
      attrs = {:tracker_id => @issue.tracker, :parent_issue_id => @issue.parent_issue_id}.reject {|k,v| v.nil?}
      if params[:project_id]
        redirect_to new_project_issue_path(@issue.project, :issue => attrs)
      else
        attrs.merge! :project_id => @issue.project_id
        redirect_to new_issue_path(:issue => attrs)
      end
    else
      redirect_to issue_path(@issue)
    end
  end
end
