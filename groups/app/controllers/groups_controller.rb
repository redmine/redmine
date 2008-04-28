# redMine - project management software
# Copyright (C) 2008  FreeCode
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
  layout 'base'
  before_filter :require_admin
  
  helper :custom_fields
  
  # GET /groups
  # GET /groups.xml
  def index
    @groups = Group.find(:all, :order => 'name')
    @group = Group.new

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @groups }
    end
  end

  # GET /groups/1
  # GET /groups/1.xml
  def show
    @group = Group.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @group }
    end
  end

  # GET /groups/new
  # GET /groups/new.xml
  def new
    @group = Group.new
    @custom_values = GroupCustomField.find(:all, :order => "#{CustomField.table_name}.position").collect { |x| CustomValue.new(:custom_field => x, :customized => @group) }
    
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @group }
    end
  end

  # GET /groups/1/edit
  def edit
    @group = Group.find(params[:id])
    @custom_values = GroupCustomField.find(:all, :order => "#{CustomField.table_name}.position").collect { |x| @group.custom_values.find_by_custom_field_id(x.id) || CustomValue.new(:custom_field => x) }
  end

  # POST /groups
  # POST /groups.xml
  def create
    @group = Group.new(params[:group])
    @custom_values = GroupCustomField.find(:all, :order => "#{CustomField.table_name}.position").collect { |x| CustomValue.new(:custom_field => x, :customized => @group, :value => (params[:custom_fields] ? params["custom_fields"][x.id.to_s] : nil)) }
    @group.custom_values = @custom_values

    respond_to do |format|
      if @group.save
        flash[:notice] = l(:notice_successful_create)
        format.html { redirect_to(groups_path) }
        format.xml  { render :xml => @group, :status => :created, :location => @group }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /groups/1
  # PUT /groups/1.xml
  def update
    @group = Group.find(params[:id])
    @custom_values = GroupCustomField.find(:all, :order => "#{CustomField.table_name}.position").collect { |x| CustomValue.new(:custom_field => x, :customized => @group, :value => (params[:custom_fields] ? params["custom_fields"][x.id.to_s] : nil)) }
    @group.custom_values = @custom_values

    respond_to do |format|
      if @group.update_attributes(params[:group])
        flash[:notice] = l(:notice_successful_update)
        format.html { redirect_to(groups_path) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /groups/1
  # DELETE /groups/1.xml
  def destroy
    @group = Group.find(params[:id])
    @group.destroy

    respond_to do |format|
      format.html { redirect_to(groups_url) }
      format.xml  { head :ok }
    end
  end
end
