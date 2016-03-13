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

class PrincipalMembershipsController < ApplicationController
  layout 'admin'

  before_filter :require_admin
  before_filter :find_principal, :only => [:new, :create]
  before_filter :find_membership, :only => [:update, :destroy]

  def new
    @projects = Project.active.all
    @roles = Role.find_all_givable
    respond_to do |format|
      format.html
      format.js
    end
  end

  def create
    @members = Member.create_principal_memberships(@principal, params[:membership])
    respond_to do |format|
      format.html { redirect_to_principal @principal }
      format.js
    end
  end

  def update
    @membership.attributes = params[:membership]
    @membership.save
    respond_to do |format|
      format.html { redirect_to_principal @principal }
      format.js
    end
  end

  def destroy
    if @membership.deletable?
      @membership.destroy
    end
    respond_to do |format|
      format.html { redirect_to_principal @principal }
      format.js
    end
  end

  private

  def find_principal
    principal_id = params[:user_id] || params[:group_id]
    @principal = Principal.find(principal_id)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_membership
    @membership = Member.find(params[:id])
    @principal = @membership.principal
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def redirect_to_principal(principal)
    redirect_to edit_polymorphic_path(principal, :tab => 'memberships')
  end
end
