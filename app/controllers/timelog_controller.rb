# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
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

class TimelogController < ApplicationController
  menu_item :issues

  before_filter :find_project_for_new_time_entry, :only => [:create]
  before_filter :find_time_entry, :only => [:show, :edit, :update]
  before_filter :find_time_entries, :only => [:bulk_edit, :bulk_update, :destroy]
  before_filter :authorize, :except => [:new, :index, :report]

  before_filter :find_optional_project, :only => [:index, :report]
  before_filter :find_optional_project_for_new_time_entry, :only => [:new]
  before_filter :authorize_global, :only => [:new, :index, :report]

  accept_rss_auth :index
  accept_api_auth :index, :show, :create, :update, :destroy

  helper :sort
  include SortHelper
  helper :issues
  include TimelogHelper
  helper :custom_fields
  include CustomFieldsHelper

  def index
    sort_init 'spent_on', 'desc'
    sort_update 'spent_on' => ['spent_on', "#{TimeEntry.table_name}.created_on"],
                'user' => 'user_id',
                'activity' => 'activity_id',
                'project' => "#{Project.table_name}.name",
                'issue' => 'issue_id',
                'hours' => 'hours'

    retrieve_date_range

    scope = TimeEntry.visible.spent_between(@from, @to)
    if @issue
      scope = scope.on_issue(@issue)
    elsif @project
      scope = scope.on_project(@project, Setting.display_subprojects_issues?)
    end

    respond_to do |format|
      format.html {
        # Paginate results
        @entry_count = scope.count
        @entry_pages = Paginator.new self, @entry_count, per_page_option, params['page']
        @entries = scope.all(
          :include => [:project, :activity, :user, {:issue => :tracker}],
          :order => sort_clause,
          :limit  =>  @entry_pages.items_per_page,
          :offset =>  @entry_pages.current.offset
        )
        @total_hours = scope.sum(:hours).to_f

        render :layout => !request.xhr?
      }
      format.api  {
        @entry_count = scope.count
        @offset, @limit = api_offset_and_limit
        @entries = scope.all(
          :include => [:project, :activity, :user, {:issue => :tracker}],
          :order => sort_clause,
          :limit  => @limit,
          :offset => @offset
        )
      }
      format.atom {
        entries = scope.all(
          :include => [:project, :activity, :user, {:issue => :tracker}],
          :order => "#{TimeEntry.table_name}.created_on DESC",
          :limit => Setting.feeds_limit.to_i
        )
        render_feed(entries, :title => l(:label_spent_time))
      }
      format.csv {
        # Export all entries
        @entries = scope.all(
          :include => [:project, :activity, :user, {:issue => [:tracker, :assigned_to, :priority]}],
          :order => sort_clause
        )
        send_data(entries_to_csv(@entries), :type => 'text/csv; header=present', :filename => 'timelog.csv')
      }
    end
  end

  def report
    retrieve_date_range
    @report = Redmine::Helpers::TimeReport.new(@project, @issue, params[:criteria], params[:columns], @from, @to)

    respond_to do |format|
      format.html { render :layout => !request.xhr? }
      format.csv  { send_data(report_to_csv(@report), :type => 'text/csv; header=present', :filename => 'timelog.csv') }
    end
  end

  def show
    respond_to do |format|
      # TODO: Implement html response
      format.html { render :nothing => true, :status => 406 }
      format.api
    end
  end

  def new
    @time_entry ||= TimeEntry.new(:project => @project, :issue => @issue, :user => User.current, :spent_on => User.current.today)
    @time_entry.safe_attributes = params[:time_entry]
  end

  def create
    @time_entry ||= TimeEntry.new(:project => @project, :issue => @issue, :user => User.current, :spent_on => User.current.today)
    @time_entry.safe_attributes = params[:time_entry]

    call_hook(:controller_timelog_edit_before_save, { :params => params, :time_entry => @time_entry })

    if @time_entry.save
      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_successful_create)
          if params[:continue]
            if params[:project_id]
              redirect_to :action => 'new', :project_id => @time_entry.project, :issue_id => @time_entry.issue,
                :time_entry => {:issue_id => @time_entry.issue_id, :activity_id => @time_entry.activity_id},
                :back_url => params[:back_url]
            else
              redirect_to :action => 'new', 
                :time_entry => {:project_id => @time_entry.project_id, :issue_id => @time_entry.issue_id, :activity_id => @time_entry.activity_id},
                :back_url => params[:back_url]
            end
          else
            redirect_back_or_default :action => 'index', :project_id => @time_entry.project
          end
        }
        format.api  { render :action => 'show', :status => :created, :location => time_entry_url(@time_entry) }
      end
    else
      respond_to do |format|
        format.html { render :action => 'new' }
        format.api  { render_validation_errors(@time_entry) }
      end
    end
  end

  def edit
    @time_entry.safe_attributes = params[:time_entry]
  end

  def update
    @time_entry.safe_attributes = params[:time_entry]

    call_hook(:controller_timelog_edit_before_save, { :params => params, :time_entry => @time_entry })

    if @time_entry.save
      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_successful_update)
          redirect_back_or_default :action => 'index', :project_id => @time_entry.project
        }
        format.api  { render_api_ok }
      end
    else
      respond_to do |format|
        format.html { render :action => 'edit' }
        format.api  { render_validation_errors(@time_entry) }
      end
    end
  end

  def bulk_edit
    @available_activities = TimeEntryActivity.shared.active
    @custom_fields = TimeEntry.first.available_custom_fields
  end

  def bulk_update
    attributes = parse_params_for_bulk_time_entry_attributes(params)

    unsaved_time_entry_ids = []
    @time_entries.each do |time_entry|
      time_entry.reload
      time_entry.safe_attributes = attributes
      call_hook(:controller_time_entries_bulk_edit_before_save, { :params => params, :time_entry => time_entry })
      unless time_entry.save
        # Keep unsaved time_entry ids to display them in flash error
        unsaved_time_entry_ids << time_entry.id
      end
    end
    set_flash_from_bulk_time_entry_save(@time_entries, unsaved_time_entry_ids)
    redirect_back_or_default({:controller => 'timelog', :action => 'index', :project_id => @projects.first})
  end

  def destroy
    destroyed = TimeEntry.transaction do
      @time_entries.each do |t|
        unless t.destroy && t.destroyed?
          raise ActiveRecord::Rollback
        end
      end
    end

    respond_to do |format|
      format.html {
        if destroyed
          flash[:notice] = l(:notice_successful_delete)
        else
          flash[:error] = l(:notice_unable_delete_time_entry)
        end
        redirect_back_or_default(:action => 'index', :project_id => @projects.first)
      }
      format.api  {
        if destroyed
          render_api_ok
        else
          render_validation_errors(@time_entries)
        end
      }
    end
  end

private
  def find_time_entry
    @time_entry = TimeEntry.find(params[:id])
    unless @time_entry.editable_by?(User.current)
      render_403
      return false
    end
    @project = @time_entry.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_time_entries
    @time_entries = TimeEntry.find_all_by_id(params[:id] || params[:ids])
    raise ActiveRecord::RecordNotFound if @time_entries.empty?
    @projects = @time_entries.collect(&:project).compact.uniq
    @project = @projects.first if @projects.size == 1
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def set_flash_from_bulk_time_entry_save(time_entries, unsaved_time_entry_ids)
    if unsaved_time_entry_ids.empty?
      flash[:notice] = l(:notice_successful_update) unless time_entries.empty?
    else
      flash[:error] = l(:notice_failed_to_save_time_entries,
                        :count => unsaved_time_entry_ids.size,
                        :total => time_entries.size,
                        :ids => '#' + unsaved_time_entry_ids.join(', #'))
    end
  end

  def find_optional_project_for_new_time_entry
    if (project_id = (params[:project_id] || params[:time_entry] && params[:time_entry][:project_id])).present?
      @project = Project.find(project_id)
    end
    if (issue_id = (params[:issue_id] || params[:time_entry] && params[:time_entry][:issue_id])).present?
      @issue = Issue.find(issue_id)
      @project ||= @issue.project
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project_for_new_time_entry
    find_optional_project_for_new_time_entry
    if @project.nil?
      render_404
    end
  end

  def find_optional_project
    if !params[:issue_id].blank?
      @issue = Issue.find(params[:issue_id])
      @project = @issue.project
    elsif !params[:project_id].blank?
      @project = Project.find(params[:project_id])
    end
  end

  # Retrieves the date range based on predefined ranges or specific from/to param dates
  def retrieve_date_range
    @free_period = false
    @from, @to = nil, nil

    if params[:period_type] == '1' || (params[:period_type].nil? && !params[:period].nil?)
      case params[:period].to_s
      when 'today'
        @from = @to = Date.today
      when 'yesterday'
        @from = @to = Date.today - 1
      when 'current_week'
        @from = Date.today - (Date.today.cwday - 1)%7
        @to = @from + 6
      when 'last_week'
        @from = Date.today - 7 - (Date.today.cwday - 1)%7
        @to = @from + 6
      when 'last_2_weeks'
        @from = Date.today - 14 - (Date.today.cwday - 1)%7
        @to = @from + 13
      when '7_days'
        @from = Date.today - 7
        @to = Date.today
      when 'current_month'
        @from = Date.civil(Date.today.year, Date.today.month, 1)
        @to = (@from >> 1) - 1
      when 'last_month'
        @from = Date.civil(Date.today.year, Date.today.month, 1) << 1
        @to = (@from >> 1) - 1
      when '30_days'
        @from = Date.today - 30
        @to = Date.today
      when 'current_year'
        @from = Date.civil(Date.today.year, 1, 1)
        @to = Date.civil(Date.today.year, 12, 31)
      end
    elsif params[:period_type] == '2' || (params[:period_type].nil? && (!params[:from].nil? || !params[:to].nil?))
      begin; @from = params[:from].to_s.to_date unless params[:from].blank?; rescue; end
      begin; @to = params[:to].to_s.to_date unless params[:to].blank?; rescue; end
      @free_period = true
    else
      # default
    end

    @from, @to = @to, @from if @from && @to && @from > @to
  end

  def parse_params_for_bulk_time_entry_attributes(params)
    attributes = (params[:time_entry] || {}).reject {|k,v| v.blank?}
    attributes.keys.each {|k| attributes[k] = '' if attributes[k] == 'none'}
    attributes[:custom_field_values].reject! {|k,v| v.blank?} if attributes[:custom_field_values]
    attributes
  end
end
