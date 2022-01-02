# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

require 'csv'

class ImportsController < ApplicationController
  before_action :find_import, :only => [:show, :settings, :mapping, :run]
  before_action :authorize_import

  layout :import_layout

  helper :issues
  helper :queries

  def new
    @import = import_type.new
  end

  def create
    @import = import_type.new
    @import.user = User.current
    @import.file = params[:file]
    @import.set_default_settings(:project_id => params[:project_id])

    if @import.save
      redirect_to import_settings_path(@import)
    else
      render :action => 'new'
    end
  end

  def show
  end

  def settings
    if request.post? && @import.parse_file
      if @import.total_items == 0
        flash.now[:error] = l(:error_no_data_in_file)
      else
        redirect_to import_mapping_path(@import)
      end
    end

  rescue CSV::MalformedCSVError, EncodingError => e
    if e.is_a?(CSV::MalformedCSVError) && e.message !~ /Invalid byte sequence/
      flash.now[:error] = l(:error_invalid_csv_file_or_settings, e.message)
    else
      flash.now[:error] = l(:error_invalid_file_encoding, :encoding => ERB::Util.h(@import.settings['encoding']))
    end
  rescue SystemCallError => e
    flash.now[:error] = l(:error_can_not_read_import_file)
  end

  def mapping
    @custom_fields = @import.mappable_custom_fields

    if request.get?
      auto_map_fields
    elsif request.post?
      respond_to do |format|
        format.html do
          if params[:previous]
            redirect_to import_settings_path(@import)
          else
            redirect_to import_run_path(@import)
          end
        end
        format.js # updates mapping form on project or tracker change
      end
    end
  end

  def run
    if request.post?
      @current = @import.run(
        :max_items => max_items_per_request,
        :max_time => 10.seconds
      )
      respond_to do |format|
        format.html do
          if @import.finished?
            redirect_to import_path(@import)
          else
            redirect_to import_run_path(@import)
          end
        end
        format.js
      end
    end
  end

  def current_menu(project)
    if import_layout == 'admin'
      nil
    else
      :application_menu
    end
  end

  private

  def find_import
    @import = Import.where(:user_id => User.current.id, :filename => params[:id]).first
    if @import.nil?
      render_404
      return
    elsif @import.finished? && action_name != 'show'
      redirect_to import_path(@import)
      return
    end
    update_from_params if request.post?
  end

  def update_from_params
    if params[:import_settings].present?
      @import.settings ||= {}
      @import.settings.merge!(params[:import_settings].to_unsafe_hash)
      @import.save!
    end
  end

  def max_items_per_request
    5
  end

  def import_layout
    import_type && import_type.layout || 'base'
  end

  def menu_items
    menu_item = import_type ? import_type.menu_item : nil
    {self.controller_name.to_sym => {:actions => {}, :default => menu_item}}
  end

  def authorize_import
    return render_404 unless import_type
    return render_403 unless import_type.authorized?(User.current)
  end

  def import_type
    return @import_type if defined? @import_type

    @import_type =
      if @import
        @import.class
      else
        type =
          begin
            Object.const_get(params[:type])
          rescue
            nil
          end
        type && type < Import ? type : nil
      end
  end

  def auto_map_fields
    # Try to auto map fields only when settings['enconding'] is present
    # otherwhise, the import fails for non UTF-8 files because the headers
    # cannot be retrieved (Invalid byte sequence in UTF-8)
    return if @import.settings['encoding'].blank?

    mappings = @import.settings['mapping'] ||= {}
    headers = @import.headers.map{|header| header&.downcase}

    # Core fields
    import_type::AUTO_MAPPABLE_FIELDS.each do |field_nm, label_nm|
      next if mappings.include?(field_nm)

      index = headers.index(field_nm) || headers.index(l(label_nm).downcase)
      if index
        mappings[field_nm] = index
      end
    end

    # Custom fields
    @custom_fields.each do |field|
      field_nm = "cf_#{field.id}"
      next if mappings.include?(field_nm)

      index = headers.index(field_nm) || headers.index(field.name.downcase)
      if index
        mappings[field_nm] = index
      end
    end
    mappings
  end
end
