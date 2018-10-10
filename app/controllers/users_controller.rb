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

class UsersController < ApplicationController
  layout 'admin'
  self.main_menu = false

  before_action :require_admin, :except => :show
  before_action ->{ find_user(false) }, :only => :show
  before_action :find_user, :only => [:edit, :update, :destroy]
  accept_api_auth :index, :show, :create, :update, :destroy

  helper :sort
  include SortHelper
  helper :custom_fields
  include CustomFieldsHelper
  include UsersHelper
  helper :principal_memberships
  helper :activities
  include ActivitiesHelper

  require_sudo_mode :create, :update, :destroy

  def index
    sort_init 'login', 'asc'
    sort_update %w(login firstname lastname admin created_on last_login_on)

    case params[:format]
    when 'xml', 'json'
      @offset, @limit = api_offset_and_limit
    else
      @limit = per_page_option
    end

    @status = params[:status] || 1

    scope = User.logged.status(@status).preload(:email_address)
    scope = scope.like(params[:name]) if params[:name].present?
    scope = scope.in_group(params[:group_id]) if params[:group_id].present?

    @user_count = scope.count
    @user_pages = Paginator.new @user_count, @limit, params['page']
    @offset ||= @user_pages.offset
    @users =  scope.order(sort_clause).limit(@limit).offset(@offset).to_a

    respond_to do |format|
      format.html {
        @groups = Group.givable.sort
        render :layout => !request.xhr?
      }
      format.csv {
        send_data(users_to_csv(scope.order(sort_clause)), :type => 'text/csv; header=present', :filename => 'users.csv')
      }
      format.api
    end
  end

  def show
    unless @user.visible?
      render_404
      return
    end

    # show projects based on current user visibility
    @memberships = @user.memberships.preload(:roles, :project).where(Project.visible_condition(User.current)).to_a

    respond_to do |format|
      format.html {
        events = Redmine::Activity::Fetcher.new(User.current, :author => @user).events(nil, nil, :limit => 10)
        @events_by_day = events.group_by {|event| User.current.time_to_date(event.event_datetime)}
        render :layout => 'base'
      }
      format.api
    end
  end

  def new
    @user = User.new(:language => Setting.default_language, :mail_notification => Setting.default_notification_option)
    @user.safe_attributes = params[:user]
    @auth_sources = AuthSource.all
  end

  def create
    @user = User.new(:language => Setting.default_language, :mail_notification => Setting.default_notification_option, :admin => false)
    @user.safe_attributes = params[:user]
    @user.password, @user.password_confirmation = params[:user][:password], params[:user][:password_confirmation] unless @user.auth_source_id
    @user.pref.safe_attributes = params[:pref]

    if @user.save
      Mailer.deliver_account_information(@user, @user.password) if params[:send_information]

      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_user_successful_create, :id => view_context.link_to(@user.login, user_path(@user)))
          if params[:continue]
            attrs = {:generate_password => @user.generate_password }
            redirect_to new_user_path(:user => attrs)
          else
            redirect_to edit_user_path(@user)
          end
        }
        format.api  { render :action => 'show', :status => :created, :location => user_url(@user) }
      end
    else
      @auth_sources = AuthSource.all
      # Clear password input
      @user.password = @user.password_confirmation = nil

      respond_to do |format|
        format.html { render :action => 'new' }
        format.api  { render_validation_errors(@user) }
      end
    end
  end

  def edit
    @auth_sources = AuthSource.all
    @membership ||= Member.new
  end

  def update
    if params[:user][:password].present? && (@user.auth_source_id.nil? || params[:user][:auth_source_id].blank?)
      @user.password, @user.password_confirmation = params[:user][:password], params[:user][:password_confirmation]
    end
    @user.safe_attributes = params[:user]
    # Was the account actived ? (do it before User#save clears the change)
    was_activated = (@user.status_change == [User::STATUS_REGISTERED, User::STATUS_ACTIVE])
    # TODO: Similar to My#account
    @user.pref.safe_attributes = params[:pref]

    if @user.save
      @user.pref.save

      if was_activated
        Mailer.deliver_account_activated(@user)
      elsif @user.active? && params[:send_information] && @user != User.current
        Mailer.deliver_account_information(@user, @user.password)
      end

      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_successful_update)
          redirect_to_referer_or edit_user_path(@user)
        }
        format.api  { render_api_ok }
      end
    else
      @auth_sources = AuthSource.all
      @membership ||= Member.new
      # Clear password input
      @user.password = @user.password_confirmation = nil

      respond_to do |format|
        format.html { render :action => :edit }
        format.api  { render_validation_errors(@user) }
      end
    end
  end

  def destroy
    @user.destroy
    respond_to do |format|
      format.html { redirect_back_or_default(users_path) }
      format.api  { render_api_ok }
    end
  end

  private

  def find_user(logged = true)
    if params[:id] == 'current'
      require_login || return
      @user = User.current
    elsif logged
      @user = User.logged.find(params[:id])
    else
      @user = User.find(params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
