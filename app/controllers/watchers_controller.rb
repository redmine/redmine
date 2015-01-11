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

class WatchersController < ApplicationController
  before_filter :require_login, :find_watchables, :only => [:watch, :unwatch]

  def watch
    set_watcher(@watchables, User.current, true)
  end

  def unwatch
    set_watcher(@watchables, User.current, false)
  end

  before_filter :find_project, :authorize, :only => [:new, :create, :append, :destroy, :autocomplete_for_user]
  accept_api_auth :create, :destroy

  def new
    @users = users_for_new_watcher
  end

  def create
    user_ids = []
    if params[:watcher].is_a?(Hash)
      user_ids << (params[:watcher][:user_ids] || params[:watcher][:user_id])
    else
      user_ids << params[:user_id]
    end
    users = User.active.visible.where(:id => user_ids.flatten.compact.uniq)
    users.each do |user|
      Watcher.create(:watchable => @watched, :user => user)
    end
    respond_to do |format|
      format.html { redirect_to_referer_or {render :text => 'Watcher added.', :layout => true}}
      format.js { @users = users_for_new_watcher }
      format.api { render_api_ok }
    end
  end

  def append
    if params[:watcher].is_a?(Hash)
      user_ids = params[:watcher][:user_ids] || [params[:watcher][:user_id]]
      @users = User.active.visible.where(:id => user_ids).to_a
    end
    if @users.blank?
      render :nothing => true
    end
  end

  def destroy
    @watched.set_watcher(User.visible.find(params[:user_id]), false)
    respond_to do |format|
      format.html { redirect_to :back }
      format.js
      format.api { render_api_ok }
    end
  end

  def autocomplete_for_user
    @users = users_for_new_watcher
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

  def find_watchables
    klass = Object.const_get(params[:object_type].camelcase) rescue nil
    if klass && klass.respond_to?('watched_by')
      @watchables = klass.where(:id => Array.wrap(params[:object_id])).to_a
      raise Unauthorized if @watchables.any? {|w|
        if w.respond_to?(:visible?)
          !w.visible?
        elsif w.respond_to?(:project) && w.project
          !w.project.visible?
        end
      }
    end
    render_404 unless @watchables.present?
  end

  def set_watcher(watchables, user, watching)
    watchables.each do |watchable|
      watchable.set_watcher(user, watching)
    end
    respond_to do |format|
      format.html { redirect_to_referer_or {render :text => (watching ? 'Watcher added.' : 'Watcher removed.'), :layout => true}}
      format.js { render :partial => 'set_watcher', :locals => {:user => user, :watched => watchables} }
    end
  end

  def users_for_new_watcher
    scope = nil
    if params[:q].blank? && @project.present?
      scope = @project.users
    else
      scope = User.all.limit(100)
    end
    users = scope.active.visible.sorted.like(params[:q]).to_a
    if @watched
      users -= @watched.watcher_users
    end
    users
  end
end
