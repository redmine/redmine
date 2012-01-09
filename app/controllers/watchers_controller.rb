# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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

  verify :method => :post,
         :only => [ :watch, :unwatch ],
         :render => { :nothing => true, :status => :method_not_allowed }

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
    respond_to do |format|
      format.js do
        render :update do |page|
          page.replace_html 'ajax-modal', :partial => 'watchers/new', :locals => {:watched => @watched}
          page << "showModal('ajax-modal', '400px');"
          page << "$('ajax-modal').addClassName('new-watcher');"
        end
      end
    end
  end

  def create
    if params[:watcher].is_a?(Hash) && request.post?
      user_ids = params[:watcher][:user_ids] || [params[:watcher][:user_id]]
      user_ids.each do |user_id|
        Watcher.create(:watchable => @watched, :user_id => user_id)
      end
    end
    respond_to do |format|
      format.html { redirect_to :back }
      format.js do
        render :update do |page|
          page.replace_html 'ajax-modal', :partial => 'watchers/new', :locals => {:watched => @watched}
          page.replace_html 'watchers', :partial => 'watchers/watchers', :locals => {:watched => @watched}
        end
      end
    end
  rescue ::ActionController::RedirectBackError
    render :text => 'Watcher added.', :layout => true
  end

  def destroy
    @watched.set_watcher(User.find(params[:user_id]), false) if request.post?
    respond_to do |format|
      format.html { redirect_to :back }
      format.js do
        render :update do |page|
          page.replace_html 'watchers', :partial => 'watchers/watchers', :locals => {:watched => @watched}
        end
      end
    end
  end

  def autocomplete_for_user
    @users = User.active.like(params[:q]).find(:all, :limit => 100) - @watched.watcher_users
    render :layout => false
  end

private
  def find_project
    klass = Object.const_get(params[:object_type].camelcase)
    return false unless klass.respond_to?('watched_by')
    @watched = klass.find(params[:object_id])
    @project = @watched.project
  rescue
    render_404
  end

  def set_watcher(user, watching)
    @watched.set_watcher(user, watching)
    respond_to do |format|
      format.html { redirect_to :back }
      format.js do
        render(:update) do |page|
          c = watcher_css(@watched)
          page.select(".#{c}").each do |item|
            page.replace_html item, watcher_link(@watched, user)
          end
        end
      end
    end
  rescue ::ActionController::RedirectBackError
    render :text => (watching ? 'Watcher added.' : 'Watcher removed.'), :layout => true
  end
end
