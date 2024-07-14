# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
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
  default_search_scope :issues

  before_action :find_issue, :only => [:show, :edit, :update, :issue_tab]
  before_action :find_issues, :only => [:bulk_edit, :bulk_update, :destroy]
  before_action :authorize, :except => [:index, :new, :create]
  before_action :find_optional_project, :only => [:index, :new, :create]
  before_action :build_new_issue_from_params, :only => [:new, :create]
  accept_atom_auth :index, :show
  accept_api_auth :index, :show, :create, :update, :destroy

  rescue_from Query::StatementInvalid, :with => :query_statement_invalid
  rescue_from Query::QueryError, :with => :query_error

  helper :journals
  helper :projects
  helper :custom_fields
  helper :issue_relations
  helper :watchers
  helper :attachments
  helper :queries
  include QueriesHelper
  helper :repositories
  helper :timelog

  def index
    use_session = !request.format.csv?
    retrieve_default_query(use_session)
    retrieve_query(IssueQuery, use_session)

    if @query.valid?
      respond_to do |format|
        format.html do
          @issue_count = @query.issue_count
          @issue_pages = Paginator.new @issue_count, per_page_option, params['page']
          @issues = @query.issues(:offset => @issue_pages.offset, :limit => @issue_pages.per_page)
          render :layout => !request.xhr?
        end
        format.api do
          @offset, @limit = api_offset_and_limit
          @query.column_names = %w(author)
          @issue_count = @query.issue_count
          @issues = @query.issues(:offset => @offset, :limit => @limit)
          Issue.load_visible_relations(@issues) if include_in_api_response?('relations')
          if User.current.allowed_to?(:view_time_entries, nil, :global => true)
            Issue.load_visible_spent_hours(@issues)
            Issue.load_visible_total_spent_hours(@issues)
          end
        end
        format.atom do
          issues = @query.issues(:limit => Setting.feeds_limit.to_i)
          render_feed(issues,
                      :title => "#{@project || Setting.app_title}: #{l(:label_issue_plural)}")
        end
        format.csv do
          issues = @query.issues(:limit => Setting.issues_export_limit.to_i)
          send_data(query_to_csv(issues, @query, params[:csv]),
                    :type => 'text/csv; header=present', :filename => "#{filename_for_export(@query, 'issues')}.csv")
        end
        format.pdf do
          @issues = @query.issues(:limit => Setting.issues_export_limit.to_i)
          send_file_headers! :type => 'application/pdf', :filename => "#{filename_for_export(@query, 'issues')}.pdf"
        end
      end
    else
      respond_to do |format|
        format.html {render :layout => !request.xhr?}
        format.any(:atom, :csv, :pdf) {head :unprocessable_content}
        format.api {render_validation_errors(@query)}
      end
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def show
    if !api_request? || include_in_api_response?('journals')
      @journals = @issue.visible_journals_with_index
      @journals.reverse! if User.current.wants_comments_in_reverse_order?
    end
    if !api_request? || include_in_api_response?('relations')
      @relations = @issue.relations.select {|r| r.other_issue(@issue)&.visible?}
    end
    if !api_request? || include_in_api_response?('allowed_statuses')
      @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
    end

    if User.current.allowed_to?(:view_time_entries, @project)
      Issue.load_visible_spent_hours([@issue])
      Issue.load_visible_total_spent_hours([@issue])
    end

    respond_to do |format|
      format.html do
        @priorities = IssuePriority.active
        @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
        @time_entries = @issue.time_entries.visible.preload(:activity, :user)
        @relation = IssueRelation.new
        @has_changesets = @issue.changesets.visible.preload(:repository, :user).exists?
        retrieve_previous_and_next_issue_ids
        render :template => 'issues/show'
      end
      format.api do
        if include_in_api_response?('changesets')
          @changesets = @issue.changesets.visible.preload(:repository, :user).to_a
          @changesets.reverse! if User.current.wants_comments_in_reverse_order?
        end
      end
      format.atom do
        render :template => 'journals/index', :layout => false,
        :content_type => 'application/atom+xml'
      end
      format.pdf do
        send_file_headers!(:type => 'application/pdf',
                           :filename => "#{@project.identifier}-#{@issue.id}.pdf")
      end
    end
  end

  def new
    respond_to do |format|
      format.html {render :action => 'new', :layout => !request.xhr?}
      format.js
    end
  end

  def create
    unless User.current.allowed_to?(:add_issues, @issue.project, :global => true)
      raise ::Unauthorized
    end

    call_hook(:controller_issues_new_before_save, {:params => params, :issue => @issue})
    @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
    if @issue.save
      call_hook(:controller_issues_new_after_save, {:params => params, :issue => @issue})
      respond_to do |format|
        format.html do
          render_attachment_warning_if_needed(@issue)
          flash[:notice] =
            l(:notice_issue_successful_create,
              :id => view_context.link_to("##{@issue.id}", issue_path(@issue),
                                          :title => @issue.subject))
          redirect_after_create
        end
        format.api do
          render :action => 'show', :status => :created,
          :location => issue_url(@issue)
        end
      end
      return
    else
      respond_to do |format|
        format.html do
          if @issue.project.nil?
            render_error :status => 422
          else
            render :action => 'new'
          end
        end
        format.api  {render_validation_errors(@issue)}
      end
    end
  end

  def edit
    return unless update_issue_from_params

    respond_to do |format|
      format.html {}
      format.js
    end
  end

  def update
    return unless update_issue_from_params

    attachments = params[:attachments] || params.dig(:issue, :uploads)
    if @issue.attachments_addable?
      @issue.save_attachments(attachments)
    else
      attachments = attachments.to_unsafe_hash if attachments.respond_to?(:to_unsafe_hash)
      if [Hash, Array].any? { |klass| attachments.is_a?(klass) } && attachments.any?
        flash[:warning] = l(:warning_attachments_not_saved, attachments.size)
      end
    end

    saved = false
    begin
      saved = save_issue_with_child_records
    rescue ActiveRecord::StaleObjectError
      @issue.detach_saved_attachments
      @conflict = true
      if params[:last_journal_id]
        @conflict_journals = @issue.journals_after(params[:last_journal_id]).to_a
        unless User.current.allowed_to?(:view_private_notes, @issue.project)
          @conflict_journals.reject!(&:private_notes?)
        end
      end
    end

    if saved
      render_attachment_warning_if_needed(@issue)
      unless @issue.current_journal.new_record? || params[:no_flash]
        flash[:notice] = l(:notice_successful_update)
      end
      respond_to do |format|
        format.html do
          redirect_back_or_default(
            issue_path(@issue, previous_and_next_issue_ids_params)
          )
        end
        format.api  {render_api_ok}
      end
    else
      respond_to do |format|
        format.html {render :action => 'edit'}
        format.api  {render_validation_errors(@issue)}
      end
    end
  end

  def issue_tab
    return render_error :status => 422 unless request.xhr?

    tab = params[:name]

    case tab
    when 'time_entries'
      @time_entries = @issue.time_entries.visible.preload(:activity, :user).to_a
      render :partial => 'issues/tabs/time_entries', :locals => {:time_entries => @time_entries}
    when 'changesets'
      @changesets = @issue.changesets.visible.preload(:repository, :user).to_a
      @changesets.reverse! if User.current.wants_comments_in_reverse_order?
      render :partial => 'issues/tabs/changesets', :locals => {:changesets => @changesets, :project => @project}
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
    else
      unless @issues.all?(&:attributes_editable?)
        raise ::Unauthorized
      end
    end

    edited_issues = Issue.where(:id => @issues.map(&:id)).to_a

    @values_by_custom_field = {}
    edited_issues.each do |issue|
      issue.custom_field_values.each do |c|
        if c.value_present?
          @values_by_custom_field[c.custom_field] ||= []
          @values_by_custom_field[c.custom_field] << issue.id
        end
      end
    end

    @allowed_projects = Issue.allowed_target_projects
    if params[:issue]
      @target_project = @allowed_projects.detect {|p| p.id.to_s == params[:issue][:project_id].to_s}
      if @target_project
        target_projects = [@target_project]
        edited_issues.each {|issue| issue.project = @target_project}
      end
    end
    target_projects ||= @projects

    @trackers = target_projects.map {|p| Issue.allowed_target_trackers(p)}.reduce(:&)
    if params[:issue]
      @target_tracker = @trackers.detect {|t| t.id.to_s == params[:issue][:tracker_id].to_s}
      if @target_tracker
        edited_issues.each {|issue| issue.tracker = @target_tracker}
      end
    end

    if @copy
      # Copied issues will get their default statuses
      @available_statuses = []
    else
      @available_statuses = edited_issues.map(&:new_statuses_allowed_to).reduce(:&)
    end
    if params[:issue]
      @target_status = @available_statuses.detect {|t| t.id.to_s == params[:issue][:status_id].to_s}
      if @target_status
        edited_issues.each {|issue| issue.status = @target_status}
      end
    end

    edited_issues.each do |issue|
      issue.custom_field_values.each do |c|
        if c.value_present? && @values_by_custom_field[c.custom_field]
          @values_by_custom_field[c.custom_field].delete(issue.id)
        end
      end
    end
    @values_by_custom_field.delete_if {|k, v| v.blank?}
    @custom_fields =
      edited_issues.map{|i| i.editable_custom_fields}.
        reduce(:&).select {|field| field.format.bulk_edit_supported}
    @assignables = target_projects.map(&:assignable_users).reduce(:&)
    @versions = target_projects.map {|p| p.shared_versions.open}.reduce(:&)
    @categories = target_projects.map {|p| p.issue_categories}.reduce(:&)
    if @copy
      @attachments_present = @issues.detect {|i| i.attachments.any?}.present? &&
                               (Setting.copy_attachments_on_issue_copy == 'ask')
      @subtasks_present = @issues.detect {|i| !i.leaf?}.present?
      @watchers_present = User.current.allowed_to?(:add_issue_watchers, @projects) &&
                            Watcher.where(:watchable_type => 'Issue',
                                          :watchable_id => @issues.map(&:id)).exists?
    end

    @safe_attributes = edited_issues.map(&:safe_attribute_names).reduce(:&)

    @issue_params = params[:issue] || {}
    @issue_params[:custom_field_values] ||= {}
  end

  def bulk_update
    @issues.sort!
    @copy = params[:copy].present?

    attributes = parse_params_for_bulk_update(params[:issue])
    copy_subtasks = (params[:copy_subtasks] == '1')
    copy_watchers = (params[:copy_watchers] == '1')

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

      unless User.current.allowed_to?(:add_issue_watchers, @projects)
        copy_watchers = false
      end
    else
      unless @issues.all?(&:attributes_editable?)
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
        issue = orig_issue.copy(
          {},
          :attachments => copy_attachments?(params[:copy_attachments]),
          :subtasks => copy_subtasks,
          :watchers => copy_watchers,
          :link => link_copy?(params[:link_copy])
        )
      else
        issue = orig_issue
      end
      journal = issue.init_journal(User.current, params[:notes])
      issue.safe_attributes = attributes
      call_hook(:controller_issues_bulk_edit_before_save, {:params => params, :issue => issue})
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
    raise Unauthorized unless @issues.all?(&:deletable?)

    # all issues and their descendants are about to be deleted
    issues_and_descendants_ids = Issue.self_and_descendants(@issues).pluck(:id)
    time_entries = TimeEntry.where(:issue_id => issues_and_descendants_ids)
    @hours = time_entries.sum(:hours).to_f

    if @hours > 0
      case params[:todo]
      when 'destroy'
        # nothing to do
      when 'nullify'
        if Setting.timelog_required_fields.include?('issue_id')
          flash.now[:error] = l(:field_issue) + " " + ::I18n.t('activerecord.errors.messages.blank')
          return
        else
          time_entries.update_all(:issue_id => nil)
        end
      when 'reassign'
        reassign_to = @project && @project.issues.find_by_id(params[:reassign_to_id])
        if reassign_to.nil?
          flash.now[:error] = l(:error_issue_not_found_in_project)
          return
        elsif issues_and_descendants_ids.include?(reassign_to.id)
          flash.now[:error] = l(:error_cannot_reassign_time_entries_to_an_issue_about_to_be_deleted)
          return
        else
          time_entries.update_all(:issue_id => reassign_to.id, :project_id => reassign_to.project_id)
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
      format.html do
        flash[:notice] = l(:notice_successful_delete)
        redirect_back_or_default _project_issues_path(@project)
      end
      format.api  {render_api_ok}
    end
  end

  # Overrides Redmine::MenuManager::MenuController::ClassMethods for
  # when the "New issue" tab is enabled
  def current_menu_item
    if Setting.new_item_menu_tab == '1' && [:new, :create].include?(action_name.to_sym)
      :new_issue
    else
      super
    end
  end

  private

  def query_error(exception)
    session.delete(:issue_query)
    super
  end

  def retrieve_default_query(use_session)
    return if params[:query_id].present?
    return if api_request?
    return if params[:set_filter]

    if params[:without_default].present?
      params[:set_filter] = 1
      return
    end
    if !params[:set_filter] && use_session && session[:issue_query]
      # Don't apply the default query if a valid query id is set in the session
      query_id, project_id = session[:issue_query].values_at(:id, :project_id)
      return if query_id && project_id == @project&.id && IssueQuery.exists?(id: query_id)
    end
    if default_query = IssueQuery.default(project: @project)
      params[:query_id] = default_query.id
    end
  end

  def retrieve_previous_and_next_issue_ids
    if params[:prev_issue_id].present? || params[:next_issue_id].present?
      @prev_issue_id = params[:prev_issue_id].presence.try(:to_i)
      @next_issue_id = params[:next_issue_id].presence.try(:to_i)
      @issue_position = params[:issue_position].presence.try(:to_i)
      @issue_count = params[:issue_count].presence.try(:to_i)
    else
      retrieve_query_from_session
      if @query
        @per_page = per_page_option
        limit = 500
        issue_ids = @query.issue_ids(:limit => (limit + 1))
        if (idx = issue_ids.index(@issue.id)) && idx < limit
          if issue_ids.size < limit
            @issue_position = idx + 1
            @issue_count = issue_ids.size
          end
          @prev_issue_id = issue_ids[idx - 1] if idx > 0
          @next_issue_id = issue_ids[idx + 1] if idx < (issue_ids.size - 1)
        end
        query_params = @query.as_params
        if @issue_position
          query_params = query_params.merge(:page => (@issue_position / per_page_option) + 1, :per_page => per_page_option)
        end
        @query_path = _project_issues_path(@query.project, query_params)
      end
    end
  end

  def previous_and_next_issue_ids_params
    {
      :prev_issue_id => params[:prev_issue_id],
      :next_issue_id => params[:next_issue_id],
      :issue_position => params[:issue_position],
      :issue_count => params[:issue_count]
    }.reject {|k, v| k.blank?}
  end

  # Used by #edit and #update to set some common instance variables
  # from the params
  def update_issue_from_params
    @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
    if params[:time_entry]
      @time_entry.safe_attributes = params[:time_entry]
    end
    @issue.init_journal(User.current)
    issue_attributes = params[:issue]
    if issue_attributes && issue_attributes[:assigned_to_id] == 'me'
      issue_attributes[:assigned_to_id] = User.current.id
    end
    if issue_attributes && params[:conflict_resolution]
      case params[:conflict_resolution]
      when 'overwrite'
        issue_attributes = issue_attributes.dup
        issue_attributes.delete(:lock_version)
      when 'add_notes'
        issue_attributes = issue_attributes.slice(:notes, :private_notes)
      when 'cancel'
        redirect_to issue_path(@issue)
        return false
      end
    end
    issue_attributes = replace_none_values_with_blank(issue_attributes)
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
        @copy_attachments = copy_attachments?(params[:copy_attachments]) || request.get?
        @copy_subtasks = params[:copy_subtasks].present? || request.get?
        @copy_watchers = User.current.allowed_to?(:add_issue_watchers, @project)
        @issue.copy_from(@copy_from, :attachments => @copy_attachments,
                         :subtasks => @copy_subtasks, :watchers => @copy_watchers,
                         :link => @link_copy)
        @issue.parent_issue_id = @copy_from.parent_id
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
    @issue.start_date ||= User.current.today if Setting.default_issue_start_date_to_creation_date?

    attrs = (params[:issue] || {}).deep_dup
    if action_name == 'new' && params[:was_default_status] == attrs[:status_id]
      attrs.delete(:status_id)
    end
    if action_name == 'new' && params[:form_update_triggered_by] == 'issue_project_id'
      # Discard submitted version when changing the project on the issue form
      # so we can use the default version for the new project
      attrs.delete(:fixed_version_id)
    end
    attrs[:assigned_to_id] = User.current.id if attrs[:assigned_to_id] == 'me'
    @issue.safe_attributes = attrs

    if @issue.project
      @issue.tracker ||= @issue.allowed_target_trackers.first
      if @issue.tracker.nil?
        if @issue.project.trackers.any?
          # None of the project trackers is allowed to the user
          render_error :message => l(:error_no_tracker_allowed_for_new_issue_in_project), :status => 403
        else
          # Project has no trackers
          render_error l(:error_no_tracker_in_project)
        end
        return false
      end
      if @issue.status.nil?
        render_error l(:error_no_default_issue_status)
        return false
      end
    elsif request.get?
      render_error :message => l(:error_no_projects_with_tracker_allowed_for_new_issue), :status => 403
      return false
    end

    @priorities = IssuePriority.active
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
  end

  # Saves @issue and a time_entry from the parameters
  def save_issue_with_child_records
    Issue.transaction do
      if params[:time_entry] &&
           (params[:time_entry][:hours].present? || params[:time_entry][:comments].present?) &&
           User.current.allowed_to?(:log_time, @issue.project)
        time_entry = @time_entry || TimeEntry.new
        time_entry.project = @issue.project
        time_entry.issue = @issue
        time_entry.author = User.current
        time_entry.user = User.current
        time_entry.spent_on = User.current.today
        time_entry.safe_attributes = params[:time_entry]
        @issue.time_entries << time_entry
      end
      call_hook(
        :controller_issues_edit_before_save,
        {:params => params, :issue => @issue,
         :time_entry => time_entry,
         :journal => @issue.current_journal}
      )
      if @issue.save
        call_hook(
          :controller_issues_edit_after_save,
          {:params => params, :issue => @issue,
           :time_entry => time_entry,
           :journal => @issue.current_journal}
        )
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

  # Returns true if the attachments should be copied
  # from the original issue
  def copy_attachments?(param)
    case Setting.copy_attachments_on_issue_copy
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
      url_params = {}
      url_params[:issue] = {
        :tracker_id => @issue.tracker,
        :parent_issue_id => @issue.parent_issue_id
      }.compact
      url_params[:back_url] = params[:back_url].presence

      if params[:project_id]
        redirect_to new_project_issue_path(@issue.project, url_params)
      else
        url_params[:issue][:project_id] = @issue.project_id
        redirect_to new_issue_path(url_params)
      end
    elsif params[:follow]
      redirect_to issue_path(@issue)
    else
      redirect_back_or_default issue_path(@issue)
    end
  end
end
