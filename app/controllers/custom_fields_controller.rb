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

class CustomFieldsController < ApplicationController
  layout 'admin'

  before_filter :require_admin
  before_filter :build_new_custom_field, :only => [:new, :create]
  before_filter :find_custom_field, :only => [:edit, :update, :destroy]
  accept_api_auth :index

  def index
    respond_to do |format|
      format.html {
        @custom_fields_by_type = CustomField.all.group_by {|f| f.class.name }
      }
      format.api {
        @custom_fields = CustomField.all
      }
    end
  end

  def new
    @custom_field.field_format = 'string' if @custom_field.field_format.blank?
    @custom_field.default_value = nil
  end

  def create
    if @custom_field.save
      flash[:notice] = l(:notice_successful_create)
      call_hook(:controller_custom_fields_new_after_save, :params => params, :custom_field => @custom_field)
      redirect_to edit_custom_field_path(@custom_field)
    else
      render :action => 'new'
    end
  end

  def edit
  end

  def update
    if @custom_field.update_attributes(params[:custom_field])
      flash[:notice] = l(:notice_successful_update)
      call_hook(:controller_custom_fields_edit_after_save, :params => params, :custom_field => @custom_field)
      redirect_to edit_custom_field_path(@custom_field)
    else
      render :action => 'edit'
    end
  end

  def destroy
    begin
      @custom_field.destroy
    rescue
      flash[:error] = l(:error_can_not_delete_custom_field)
    end
    redirect_to custom_fields_path(:tab => @custom_field.class.name)
  end

  private

  def build_new_custom_field
    @custom_field = CustomField.new_subclass_instance(params[:type], params[:custom_field])
    if @custom_field.nil?
      render :action => 'select_type'
    end
  end

  def find_custom_field
    @custom_field = CustomField.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
