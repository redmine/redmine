# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
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

class WatchersController < ApplicationController
  before_filter :find_project
  before_filter :require_login, :check_project_privacy, :only => [:watch, :unwatch]
  before_filter :authorize, :only => [:new, :destroy]

  def watch
    if @watched.respond_to?(:visible?) && !@watched.visible?(User.current)
      render_403
    else
      set_watcher(User.current, true)
    end
  end

  def unwatch
    set_watcher(User.current, false)
  end

  def new
  end

  def create
    if params[:watcher].is_a?(Hash) && request.post?
      user_ids = params[:watcher][:user_ids] || [params[:watcher][:user_id]]
      user_ids.each do |user_id|
        Watcher.create(:watchable => @watched, :user_id => user_id)
      end
    end
    respond_to do |format|
      format.html { redirect_to_referer_or {render :text => 'Watcher added.', :layout => true}}
      format.js
    end
  end

  def append
    if params[:watcher].is_a?(Hash)
      user_ids = params[:watcher][:user_ids] || [params[:watcher][:user_id]]
      @users = User.active.find_all_by_id(user_ids)
    end
  end

  def destroy
    @watched.set_watcher(User.find(params[:user_id]), false) if request.post?
    respond_to do |format|
      format.html { redirect_to :back }
      format.js
    end
  end

  def autocomplete_for_user
    @users = User.active.like(params[:q]).limit(100).all
    if @watched
      @users -= @watched.watcher_users
    end
    render :layout => false
  end

private
  def find_project
    if params[:object_type] && params[:object_id]
      klass = Object.const_get(params[:object_type].camelcase)
      return false unless klass.respond_to?('watched_by')
      @watched = klass.find(params[:object_id])
      @project = @watched.project
    elsif params[:project_id]
      @project = Project.visible.find_by_param(params[:project_id])
    end
  rescue
    render_404
  end

  def set_watcher(user, watching)
    @watched.set_watcher(user, watching)
    respond_to do |format|
      format.html { redirect_to_referer_or {render :text => (watching ? 'Watcher added.' : 'Watcher removed.'), :layout => true}}
      format.js { render :partial => 'set_watcher', :locals => {:user => user, :watched => @watched} }
    end
  end
end
