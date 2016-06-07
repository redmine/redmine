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

require 'csv'

class ImportsController < ApplicationController

  before_filter :find_import, :only => [:show, :settings, :mapping, :run]
  before_filter :authorize_global

  helper :issues

  def new
  end

  def create
    @import = IssueImport.new
    @import.user = User.current
    @import.file = params[:file]
    @import.set_default_settings

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
      redirect_to import_mapping_path(@import)
    end

  rescue CSV::MalformedCSVError => e
    flash.now[:error] = l(:error_invalid_csv_file_or_settings)
  rescue ArgumentError, Encoding::InvalidByteSequenceError => e
    flash.now[:error] = l(:error_invalid_file_encoding, :encoding => ERB::Util.h(@import.settings['encoding']))
  rescue SystemCallError => e
    flash.now[:error] = l(:error_can_not_read_import_file)
  end

  def mapping
    @custom_fields = @import.mappable_custom_fields

    if request.post?
      respond_to do |format|
        format.html {
          if params[:previous]
            redirect_to import_settings_path(@import)
          else
            redirect_to import_run_path(@import)
          end
        }
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
        format.html {
          if @import.finished?
            redirect_to import_path(@import)
          else
            redirect_to import_run_path(@import)
          end
        }
        format.js
      end
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
    if params[:import_settings].is_a?(Hash)
      @import.settings ||= {}
      @import.settings.merge!(params[:import_settings])
      @import.save!
    end
  end

  def max_items_per_request
    5
  end
end
