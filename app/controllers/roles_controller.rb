# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class RolesController < ApplicationController
  layout 'admin'

  before_filter :require_admin, :except => [:index, :show]
  before_filter :require_admin_or_api_request, :only => [:index, :show]
  before_filter :find_role, :only => [:show, :edit, :update, :destroy]
  accept_api_auth :index, :show

  require_sudo_mode :create, :update, :destroy

  def index
    respond_to do |format|
      format.html {
        @roles = Role.sorted.to_a
        render :layout => false if request.xhr?
      }
      format.api {
        @roles = Role.givable.to_a
      }
    end
  end

  def show
    respond_to do |format|
      format.api
    end
  end

  def new
    # Prefills the form with 'Non member' role permissions by default
    @role = Role.new(params[:role] || {:permissions => Role.non_member.permissions})
    if params[:copy].present? && @copy_from = Role.find_by_id(params[:copy])
      @role.copy_from(@copy_from)
    end
    @roles = Role.sorted.to_a
  end

  def create
    @role = Role.new(params[:role])
    if request.post? && @role.save
      # workflow copy
      if !params[:copy_workflow_from].blank? && (copy_from = Role.find_by_id(params[:copy_workflow_from]))
        @role.workflow_rules.copy(copy_from)
      end
      flash[:notice] = l(:notice_successful_create)
      redirect_to roles_path
    else
      @roles = Role.sorted.to_a
      render :action => 'new'
    end
  end

  def edit
  end

  def update
    if @role.update_attributes(params[:role])
      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_successful_update)
          redirect_to roles_path(:page => params[:page])
        }
        format.js { render :nothing => true }
      end
    else
      respond_to do |format|
        format.html { render :action => 'edit' }
        format.js { render :nothing => true, :status => 422 }
      end
    end
  end

  def destroy
    @role.destroy
    redirect_to roles_path
  rescue
    flash[:error] =  l(:error_can_not_remove_role)
    redirect_to roles_path
  end

  def permissions
    @roles = Role.sorted.to_a
    @permissions = Redmine::AccessControl.permissions.select { |p| !p.public? }
    if request.post?
      @roles.each do |role|
        role.permissions = params[:permissions][role.id.to_s]
        role.save
      end
      flash[:notice] = l(:notice_successful_update)
      redirect_to roles_path
    end
  end

  private

  def find_role
    @role = Role.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
