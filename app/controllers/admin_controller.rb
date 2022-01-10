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

class AdminController < ApplicationController
  layout 'admin'
  self.main_menu = false
  menu_item :projects, :only => :projects
  menu_item :plugins, :only => :plugins
  menu_item :info, :only => :info

  before_action :require_admin

  def index
    @no_configuration_data = Redmine::DefaultData::Loader::no_data?
  end

  def projects
    @status = params[:status] || 1

    scope = Project.status(@status).sorted
    scope = scope.like(params[:name]) if params[:name].present?

    @project_count = scope.count
    @project_pages = Paginator.new @project_count, per_page_option, params['page']
    @projects = scope.limit(@project_pages.per_page).offset(@project_pages.offset).to_a

    render :action => "projects", :layout => false if request.xhr?
  end

  def plugins
    @plugins = Redmine::Plugin.all
  end

  # Loads the default configuration
  # (roles, trackers, statuses, workflow, enumerations)
  def default_configuration
    if request.post?
      begin
        Redmine::DefaultData::Loader::load(params[:lang])
        flash[:notice] = l(:notice_default_data_loaded)
      rescue => e
        flash[:error] = l(:error_can_t_load_default_data, ERB::Util.h(e.message))
      end
    end
    redirect_to admin_path
  end

  def test_email
    begin
      Mailer.deliver_test_email(User.current)
      flash[:notice] = l(:notice_email_sent, ERB::Util.h(User.current.mail))
    rescue => e
      flash[:error] = l(:notice_email_error, ERB::Util.h(Redmine::CodesetUtil.replace_invalid_utf8(e.message.dup)))
    end
    redirect_to settings_path(:tab => 'notifications')
  end

  def info
    @checklist = [
      [:text_default_administrator_account_changed, User.default_admin_account_changed?],
      [:text_file_repository_writable, File.writable?(Attachment.storage_path)],
      ["#{l :text_plugin_assets_writable} (./public/plugin_assets)",   File.writable?(Redmine::Plugin.public_directory)],
      [:text_all_migrations_have_been_run, !ActiveRecord::Base.connection.migration_context.needs_migration?],
      [:text_minimagick_available,     Object.const_defined?(:MiniMagick)],
      [:text_convert_available,        Redmine::Thumbnail.convert_available?],
      [:text_gs_available,             Redmine::Thumbnail.gs_available?]
    ]
  end
end
