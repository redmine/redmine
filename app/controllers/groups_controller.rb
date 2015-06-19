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

class GroupsController < ApplicationController
  layout 'admin'

  before_filter :require_admin
  before_filter :find_group, :except => [:index, :new, :create]
  accept_api_auth :index, :show, :create, :update, :destroy, :add_users, :remove_user

  require_sudo_mode :add_users, :remove_user, :create, :update, :destroy, :edit_membership, :destroy_membership

  helper :custom_fields
  helper :principal_memberships

  def index
    respond_to do |format|
      format.html {
        @groups = Group.sorted.to_a
        @user_count_by_group_id = user_count_by_group_id
      }
      format.api {
        scope = Group.sorted
        scope = scope.givable unless params[:builtin] == '1'
        @groups = scope.to_a
      }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.api
    end
  end

  def new
    @group = Group.new
  end

  def create
    @group = Group.new
    @group.safe_attributes = params[:group]

    respond_to do |format|
      if @group.save
        format.html {
          flash[:notice] = l(:notice_successful_create)
          redirect_to(params[:continue] ? new_group_path : groups_path)
        }
        format.api  { render :action => 'show', :status => :created, :location => group_url(@group) }
      else
        format.html { render :action => "new" }
        format.api  { render_validation_errors(@group) }
      end
    end
  end

  def edit
  end

  def update
    @group.safe_attributes = params[:group]

    respond_to do |format|
      if @group.save
        flash[:notice] = l(:notice_successful_update)
        format.html { redirect_to(groups_path) }
        format.api  { render_api_ok }
      else
        format.html { render :action => "edit" }
        format.api  { render_validation_errors(@group) }
      end
    end
  end

  def destroy
    @group.destroy

    respond_to do |format|
      format.html { redirect_to(groups_path) }
      format.api  { render_api_ok }
    end
  end

  def new_users
  end

  def add_users
    @users = User.not_in_group(@group).where(:id => (params[:user_id] || params[:user_ids])).to_a
    @group.users << @users
    respond_to do |format|
      format.html { redirect_to edit_group_path(@group, :tab => 'users') }
      format.js
      format.api {
        if @users.any?
          render_api_ok
        else
          render_api_errors "#{l(:label_user)} #{l('activerecord.errors.messages.invalid')}"
        end
      }
    end
  end

  def remove_user
    @group.users.delete(User.find(params[:user_id])) if request.delete?
    respond_to do |format|
      format.html { redirect_to edit_group_path(@group, :tab => 'users') }
      format.js
      format.api { render_api_ok }
    end
  end

  def autocomplete_for_user
    respond_to do |format|
      format.js
    end
  end

  private

  def find_group
    @group = Group.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def user_count_by_group_id
    h = User.joins(:groups).group('group_id').count
    h.keys.each do |key|
      h[key.to_i] = h.delete(key)
    end
    h
  end
end
