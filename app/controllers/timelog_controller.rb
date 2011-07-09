# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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
  before_filter :find_project, :only => [:new, :create]
  before_filter :find_time_entry, :only => [:show, :edit, :update]
  before_filter :find_time_entries, :only => [:bulk_edit, :bulk_update, :destroy]
  before_filter :authorize, :except => [:index]
  before_filter :find_optional_project, :only => [:index]
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
    sort_update 'spent_on' => 'spent_on',
                'user' => 'user_id',
                'activity' => 'activity_id',
                'project' => "#{Project.table_name}.name",
                'issue' => 'issue_id',
                'hours' => 'hours'
    
    cond = ARCondition.new
    if @issue
      cond << "#{Issue.table_name}.root_id = #{@issue.root_id} AND #{Issue.table_name}.lft >= #{@issue.lft} AND #{Issue.table_name}.rgt <= #{@issue.rgt}"
    elsif @project
      cond << @project.project_condition(Setting.display_subprojects_issues?)
    end
    
    retrieve_date_range
    cond << ['spent_on BETWEEN ? AND ?', @from, @to]

    respond_to do |format|
      format.html {
        # Paginate results
        @entry_count = TimeEntry.visible.count(:include => [:project, :issue], :conditions => cond.conditions)
        @entry_pages = Paginator.new self, @entry_count, per_page_option, params['page']
        @entries = TimeEntry.visible.find(:all, 
                                  :include => [:project, :activity, :user, {:issue => :tracker}],
                                  :conditions => cond.conditions,
                                  :order => sort_clause,
                                  :limit  =>  @entry_pages.items_per_page,
                                  :offset =>  @entry_pages.current.offset)
        @total_hours = TimeEntry.visible.sum(:hours, :include => [:project, :issue], :conditions => cond.conditions).to_f

        render :layout => !request.xhr?
      }
      format.api  {
        @entry_count = TimeEntry.visible.count(:include => [:project, :issue], :conditions => cond.conditions)
        @offset, @limit = api_offset_and_limit
        @entries = TimeEntry.visible.find(:all, 
                                  :include => [:project, :activity, :user, {:issue => :tracker}],
                                  :conditions => cond.conditions,
                                  :order => sort_clause,
                                  :limit  => @limit,
                                  :offset => @offset)
      }
      format.atom {
        entries = TimeEntry.visible.find(:all,
                                 :include => [:project, :activity, :user, {:issue => :tracker}],
                                 :conditions => cond.conditions,
                                 :order => "#{TimeEntry.table_name}.created_on DESC",
                                 :limit => Setting.feeds_limit.to_i)
        render_feed(entries, :title => l(:label_spent_time))
      }
      format.csv {
        # Export all entries
        @entries = TimeEntry.visible.find(:all, 
                                  :include => [:project, :activity, :user, {:issue => [:tracker, :assigned_to, :priority]}],
                                  :conditions => cond.conditions,
                                  :order => sort_clause)
        send_data(entries_to_csv(@entries), :type => 'text/csv; header=present', :filename => 'timelog.csv')
      }
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
    @time_entry.attributes = params[:time_entry]
    
    call_hook(:controller_timelog_edit_before_save, { :params => params, :time_entry => @time_entry })
    render :action => 'edit'
  end

  verify :method => :post, :only => :create, :render => {:nothing => true, :status => :method_not_allowed }
  def create
    @time_entry ||= TimeEntry.new(:project => @project, :issue => @issue, :user => User.current, :spent_on => User.current.today)
    @time_entry.attributes = params[:time_entry]
    
    call_hook(:controller_timelog_edit_before_save, { :params => params, :time_entry => @time_entry })
    
    if @time_entry.save
      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_successful_update)
          redirect_back_or_default :action => 'index', :project_id => @time_entry.project
        }
        format.api  { render :action => 'show', :status => :created, :location => time_entry_url(@time_entry) }
      end
    else
      respond_to do |format|
        format.html { render :action => 'edit' }
        format.api  { render_validation_errors(@time_entry) }
      end
    end    
  end
  
  def edit
    @time_entry.attributes = params[:time_entry]
    
    call_hook(:controller_timelog_edit_before_save, { :params => params, :time_entry => @time_entry })
  end

  verify :method => :put, :only => :update, :render => {:nothing => true, :status => :method_not_allowed }
  def update
    @time_entry.attributes = params[:time_entry]
    
    call_hook(:controller_timelog_edit_before_save, { :params => params, :time_entry => @time_entry })
    
    if @time_entry.save
      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_successful_update)
          redirect_back_or_default :action => 'index', :project_id => @time_entry.project
        }
        format.api  { head :ok }
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
      time_entry.attributes = attributes
      call_hook(:controller_time_entries_bulk_edit_before_save, { :params => params, :time_entry => time_entry })
      unless time_entry.save
        # Keep unsaved time_entry ids to display them in flash error
        unsaved_time_entry_ids << time_entry.id
      end
    end
    set_flash_from_bulk_time_entry_save(@time_entries, unsaved_time_entry_ids)
    redirect_back_or_default({:controller => 'timelog', :action => 'index', :project_id => @projects.first})
  end

  verify :method => :delete, :only => :destroy, :render => {:nothing => true, :status => :method_not_allowed }
  def destroy
    @time_entries.each do |t| 
      begin
        unless t.destroy && t.destroyed?
          respond_to do |format|
            format.html {
              flash[:error] = l(:notice_unable_delete_time_entry)
              redirect_to :back
            }
            format.api  { render_validation_errors(t) }
          end
          return
        end
      rescue ::ActionController::RedirectBackError
        redirect_to :action => 'index', :project_id => @projects.first
        return
      end
    end

    respond_to do |format|
      format.html {
        flash[:notice] = l(:notice_successful_delete)
        redirect_back_or_default(:action => 'index', :project_id => @projects.first)
      }
      format.api  { head :ok }
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

  def find_project
    if (issue_id = (params[:issue_id] || params[:time_entry] && params[:time_entry][:issue_id])).present?
      @issue = Issue.find(issue_id)
      @project = @issue.project
    elsif (project_id = (params[:project_id] || params[:time_entry] && params[:time_entry][:project_id])).present?
      @project = Project.find(project_id)
    else
      render_404
      return false
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def find_optional_project
    if !params[:issue_id].blank?
      @issue = Issue.find(params[:issue_id])
      @project = @issue.project
    elsif !params[:project_id].blank?
      @project = Project.find(params[:project_id])
    end
    deny_access unless User.current.allowed_to?(:view_time_entries, @project, :global => true)
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
    @from ||= (TimeEntry.earilest_date_for_project(@project) || Date.today)
    @to   ||= (TimeEntry.latest_date_for_project(@project) || Date.today)
  end

  def parse_params_for_bulk_time_entry_attributes(params)
    attributes = (params[:time_entry] || {}).reject {|k,v| v.blank?}
    attributes.keys.each {|k| attributes[k] = '' if attributes[k] == 'none'}
    attributes[:custom_field_values].reject! {|k,v| v.blank?} if attributes[:custom_field_values]
    attributes
  end
end
