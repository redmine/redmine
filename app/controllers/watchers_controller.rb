# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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
  before_action :require_login, :find_watchables, :only => [:watch, :unwatch]

  def watch
    set_watcher(@watchables, User.current, true)
  end

  def unwatch
    set_watcher(@watchables, User.current, false)
  end

  before_action :find_project, :authorize, :only => [:new, :create, :append, :destroy, :autocomplete_for_user]
  accept_api_auth :create, :destroy

  def new
    @users = users_for_new_watcher
  end

  def create
    user_ids = []
    if params[:watcher]
      user_ids << (params[:watcher][:user_ids] || params[:watcher][:user_id])
    else
      user_ids << params[:user_id]
    end
    users = User.active.visible.where(:id => user_ids.flatten.compact.uniq)
    users.each do |user|
      @watchables.each do |watchable|
        Watcher.create(:watchable => watchable, :user => user)
      end
    end
    respond_to do |format|
      format.html { redirect_to_referer_or {render :html => 'Watcher added.', :status => 200, :layout => true}}
      format.js { @users = users_for_new_watcher }
      format.api { render_api_ok }
    end
  end

  def append
    if params[:watcher]
      user_ids = params[:watcher][:user_ids] || [params[:watcher][:user_id]]
      @users = User.active.visible.where(:id => user_ids).to_a
    end
    if @users.blank?
      head 200
    end
  end

  def destroy
    user = User.find(params[:user_id])
    @watchables.each do |watchable|
      watchable.set_watcher(user, false)
    end
    respond_to do |format|
      format.html { redirect_to_referer_or {render :html => 'Watcher removed.', :status => 200, :layout => true} }
      format.js
      format.api { render_api_ok }
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def autocomplete_for_user
    @users = users_for_new_watcher
    render :layout => false
  end

  private

  def find_project
    if params[:object_type] && params[:object_id]
      @watchables = find_objets_from_params
      @projects = @watchables.map(&:project).uniq
      if @projects.size == 1
        @project = @projects.first
      end
    elsif params[:project_id]
      @project = Project.visible.find_by_param(params[:project_id])
    end
  end

  def find_watchables
    @watchables = find_objets_from_params
    unless @watchables.present?
      render_404
    end
  end

  def set_watcher(watchables, user, watching)
    watchables.each do |watchable|
      watchable.set_watcher(user, watching)
    end
    respond_to do |format|
      format.html {
        text = watching ? 'Watcher added.' : 'Watcher removed.'
        redirect_to_referer_or {render :html => text, :status => 200, :layout => true}
      }
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
    if @watchables && @watchables.size == 1
      users -= @watchables.first.watcher_users
    end
    users
  end

  def find_objets_from_params
    klass = Object.const_get(params[:object_type].camelcase) rescue nil
    return unless klass && klass.respond_to?('watched_by')

    scope = klass.where(:id => Array.wrap(params[:object_id]))
    if klass.reflect_on_association(:project)
      scope = scope.preload(:project => :enabled_modules)
    end
    objects = scope.to_a

    raise Unauthorized if objects.any? do |w|
      if w.respond_to?(:visible?)
        !w.visible?
      elsif w.respond_to?(:project) && w.project
        !w.project.visible?
      end
    end
    objects
  end
end
