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

class SettingsController < ApplicationController
  layout 'admin'
  menu_item :plugins, :only => :plugin

  helper :queries

  before_filter :require_admin

  require_sudo_mode :index, :edit, :plugin

  def index
    edit
    render :action => 'edit'
  end

  def edit
    @notifiables = Redmine::Notifiable.all
    if request.post? && params[:settings] && params[:settings].is_a?(Hash)
      Setting.set_all_from_params(params[:settings])
      flash[:notice] = l(:notice_successful_update)
      redirect_to settings_path(:tab => params[:tab])
    else
      @options = {}
      user_format = User::USER_FORMATS.collect{|key, value| [key, value[:setting_order]]}.sort{|a, b| a[1] <=> b[1]}
      @options[:user_format] = user_format.collect{|f| [User.current.name(f[0]), f[0].to_s]}
      @deliveries = ActionMailer::Base.perform_deliveries

      @guessed_host_and_path = request.host_with_port.dup
      @guessed_host_and_path << ('/'+ Redmine::Utils.relative_url_root.gsub(%r{^\/}, '')) unless Redmine::Utils.relative_url_root.blank?

      @commit_update_keywords = Setting.commit_update_keywords.dup
      @commit_update_keywords = [{}] unless @commit_update_keywords.is_a?(Array) && @commit_update_keywords.any?

      Redmine::Themes.rescan
    end
  end

  def plugin
    @plugin = Redmine::Plugin.find(params[:id])
    unless @plugin.configurable?
      render_404
      return
    end

    if request.post?
      Setting.send "plugin_#{@plugin.id}=", params[:settings]
      flash[:notice] = l(:notice_successful_update)
      redirect_to plugin_settings_path(@plugin)
    else
      @partial = @plugin.settings[:partial]
      @settings = Setting.send "plugin_#{@plugin.id}"
    end
  rescue Redmine::PluginNotFound
    render_404
  end
end
