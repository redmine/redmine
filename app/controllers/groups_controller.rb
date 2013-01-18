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

class GroupsController < ApplicationController
  layout 'admin'

  before_filter :require_admin
  before_filter :find_group, :except => [:index, :new, :create]
  accept_api_auth :index, :show, :create, :update, :destroy, :add_users, :remove_user

  helper :custom_fields

  def index
    @groups = Group.sorted.all

    respond_to do |format|
      format.html
      format.api
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

  def add_users
    @users = User.find_all_by_id(params[:user_id] || params[:user_ids])
    @group.users << @users if request.post?
    respond_to do |format|
      format.html { redirect_to edit_group_path(@group, :tab => 'users') }
      format.js
      format.api { render_api_ok }
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

  def edit_membership
    @membership = Member.edit_membership(params[:membership_id], params[:membership], @group)
    @membership.save if request.post?
    respond_to do |format|
      format.html { redirect_to edit_group_path(@group, :tab => 'memberships') }
      format.js
    end
  end

  def destroy_membership
    Member.find(params[:membership_id]).destroy if request.post?
    respond_to do |format|
      format.html { redirect_to edit_group_path(@group, :tab => 'memberships') }
      format.js
    end
  end

  private

  def find_group
    @group = Group.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
