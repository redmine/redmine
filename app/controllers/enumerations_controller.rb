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

class EnumerationsController < ApplicationController
  layout 'admin'
  self.main_menu = false

  before_action :require_admin, :except => :index
  before_action :require_admin_or_api_request, :only => :index
  before_action :build_new_enumeration, :only => [:new, :create]
  before_action :find_enumeration, :only => [:edit, :update, :destroy]
  accept_api_auth :index

  helper :custom_fields

  def index
    respond_to do |format|
      format.html
      format.api do
        @klass = Enumeration.get_subclass(params[:type])
        if @klass
          @enumerations = @klass.shared.sorted.to_a
        else
          render_404
        end
      end
    end
  end

  def new
  end

  def create
    if request.post? && @enumeration.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to enumerations_path
    else
      render :action => 'new'
    end
  end

  def edit
  end

  def update
    if @enumeration.update(enumeration_params)
      respond_to do |format|
        format.html do
          flash[:notice] = l(:notice_successful_update)
          redirect_to enumerations_path
        end
        format.js {head 200}
      end
    else
      respond_to do |format|
        format.html {render :action => 'edit'}
        format.js {head 422}
      end
    end
  end

  def destroy
    if !@enumeration.in_use?
      # No associated objects
      @enumeration.destroy
      redirect_to enumerations_path
      return
    elsif params[:reassign_to_id].present? && (reassign_to = @enumeration.class.find_by_id(params[:reassign_to_id].to_i))
      @enumeration.destroy(reassign_to)
      redirect_to enumerations_path
      return
    end
    @enumerations = @enumeration.class.system.to_a - [@enumeration]
  end

  private

  def build_new_enumeration
    class_name = params[:enumeration] && params[:enumeration][:type] || params[:type]
    @enumeration = Enumeration.new_subclass_instance(class_name)
    if @enumeration
      @enumeration.attributes = enumeration_params || {}
    else
      render_404
    end
  end

  def find_enumeration
    @enumeration = Enumeration.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def enumeration_params
    # can't require enumeration on #new action
    cf_ids = @enumeration.available_custom_fields.map {|c| c.multiple? ? {c.id.to_s => []} : c.id.to_s}
    params.permit(:enumeration => [:name, :active, :is_default, :position, :custom_field_values => cf_ids])[:enumeration]
  end
end
