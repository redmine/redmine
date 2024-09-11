class SpentTimeController < ApplicationController

  helper :timelog
  include TimelogHelper
  helper :spent_time
  include SpentTimeHelper
  helper :custom_fields
  include CustomFieldsHelper

  # Show the initial form.
  # * If user has permissions to see spent time for every project
  # the users combobox is filled with all the users.
  # * If user has permissions to see other members' spent times of the projects he works in,
  # the users combobox is filled with their co-workers
  # * If the user only has permissions to see his own report, the users' combobox is filled with the user himself.
  def index
    @user = User.current
    @users = []
    if authorized_for?(:view_every_project_spent_time)
      @users = User.active.order(:firstname)
    elsif authorized_for?(:view_others_spent_time)
      projects = User.current.projects
      projects.each { |project| @users.concat(project.users) }
      @users.uniq!
      @users.sort_by {|obj| obj.firstname}
    else
      @users = [@user]
    end
    params[:period] ||= '7_days'
    make_time_entry_report(nil, nil, User.current)
    @assigned_issues = []
    @same_user = true
    @time_entry = TimeEntry.new
  end

  # Show the report of spent time between two dates for an user
  def report
    @user = User.current
    projects = nil
    if authorized_for?(:view_every_project_spent_time)
      # all project, which are not archived
      projects = Project.where('status!=9')
    elsif authorized_for?(:view_others_spent_time)
      projects = User.current.projects
    end
    make_time_entry_report(params[:from], params[:to], params[:user], projects)
    another_user = User.find(params[:user])
    @same_user = (@user.id == another_user.id)
    respond_to do |format|
      format.js
    end
  end

  # Delete a time entry
  def destroy_entry
    @time_entry = TimeEntry.find(params[:id])
    render_404 and return unless @time_entry
    render_403 and return unless @time_entry.editable_by?(User.current)
    @time_entry.destroy

    @user = User.current
    @from = params[:from].to_s.to_date
    @to = params[:to].to_s.to_date
    make_time_entry_report(params[:from], params[:to], @user)
    respond_to do |format|
      format.js
    end
  rescue ::ActionController::RedirectBackError
    redirect_to :action => 'index'
  end
  
  # Create a new time entry
  def create_entry
    @user = User.current
    @from, @to = params[:from].to_date, params[:to].to_date
    raise t('project_is_mandatory_error') unless time_entry_params[:project_id].present?
    raise 'invalid_date_error' unless @time_entry_date = time_entry_params[:spent_on].to_s.to_date.presence
    raise 'invalid_hours_error' unless is_numeric?(time_entry_params[:hours].to_f)

    # Project check
    begin
      @project = Project.find(time_entry_params[:project_id])
      unless allowed_project?(time_entry_params[:project_id])
        raise t('not_allowed_error', :project => @project)
      end
    rescue ActiveRecord::RecordNotFound
      raise t('cannot_find_project_error', project_id=>time_entry_params[:project_id])
    end

    # Issue check
    issue_id = (time_entry_params[:issue_id] == nil) ? 0 : time_entry_params[:issue_id].to_i
    if issue_id > 0
      begin
        @issue = Issue.find(issue_id)
      rescue ActiveRecord::RecordNotFound
        raise t('issue_not_found_error', :issue_id=> issue_id)
      end
      raise t('issue_not_in_project_error', issue=>@issue, project=>@project) unless @project.id==@issue.project_id
    end

    # Save the new record
    @time_entry = TimeEntry.new(time_entry_params.merge(:user => @user))
    render_403 and return if @time_entry && !@time_entry.editable_by?(@user)

    if @time_entry.save!
      flash[:notice] = l('time_entry_added_notice')
      respond_to do |format|
        if @time_entry_date > @to
          @to = @time_entry_date
        elsif @time_entry_date < @from
          @from = @time_entry_date
        end
        make_time_entry_report(@from, @to, @user)
        format.js
      end
    end
    rescue Exception => ex
      respond_to do |format|
        flash[:error] = ex.message
        format.js { render 'spent_time/create_entry_error'}
      end
  end

  # Update the project's issues when another project is selected
  def update_project_issues
    @to = params[:to].to_date
    @from = params[:from].to_date
    project = Project.find(params[:project_id])
    @time_entry = TimeEntry.new(:project => project)
    find_assigned_issues_by_project(params[:project_id])
    respond_to do |format|
      format.js
    end
  end

  private
  
  def is_numeric?(obj) 
   obj.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) == nil ? false : true
  end

  def allowed_project?(project_id)
    project = Project.find(project_id)
    allowed = project.allows_to?(:log_time)
    allowed ? project : nil
  end

  def time_entry_params
    params.require(:time_entry).permit(:project_id, :issue_id, :spent_on, :hours, :activity_id, :comments, :from, :to)
  end
end
