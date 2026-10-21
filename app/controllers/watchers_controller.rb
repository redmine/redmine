# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
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
  WATCHER_USERS_PER_PAGE = 100

  before_action :require_login, :find_watchables, :only => [:watch, :unwatch]

  def watch
    set_watcher(@watchables, User.current, true)
  end

  def unwatch
    set_watcher(@watchables, User.current, false)
  end

  before_action :find_project, :authorize, :only => [:new, :create, :append, :destroy, :autocomplete_for_user, :autocomplete_for_mention]
  accept_api_auth :create, :destroy

  def new
    respond_to do |format|
      format.html { render_404 }
      format.js do
        @users = users_for_new_watcher
      end
    end
  end

  def create
    return unless authorize_for_watchable_type(:add)

    user_ids = []
    if params[:watcher]
      user_ids << (params[:watcher][:user_ids] || params[:watcher][:user_id])
    else
      user_ids << params[:user_id]
    end
    user_ids = user_ids.flatten.compact.uniq
    users = Principal.assignable_watchers.where(:id => user_ids).to_a
    users.each do |user|
      @watchables.each do |watchable|
        if watchable.valid_watcher?(user)
          Watcher.create(:watchable => watchable, :user => user)
        end
      end
    end
    respond_to do |format|
      format.html do
        redirect_to_referer_or do
          render(:html => 'Watcher added.', :status => :ok, :layout => true)
        end
      end
      format.js  {@users = users_for_new_watcher}
      format.api {render_api_ok}
    end
  end

  def append
    if params[:watcher]
      user_ids = params[:watcher][:user_ids] || [params[:watcher][:user_id]]
      @users = Principal.assignable_watchers.where(:id => user_ids).to_a
    end
    if @users.blank?
      head :ok
    end
  end

  def destroy
    return unless authorize_for_watchable_type(:delete)

    user = Principal.find(params[:user_id])
    @watchables.each do |watchable|
      watchable.set_watcher(user, false)
    end
    respond_to do |format|
      format.html do
        redirect_to_referer_or do
          render(:html => 'Watcher removed.', :status => :ok, :layout => true)
        end
      end
      format.js
      format.api {render_api_ok}
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def autocomplete_for_user
    @users = users_for_new_watcher
    render :layout => false
  end

  def autocomplete_for_mention
    users = users_for_mention
    render :json => format_users_json(users)
  end

  private

  def find_project
    if params[:object_type] && params[:object_id]
      @watchables = find_objects_from_params
      @projects = @watchables.map(&:project).uniq
      if @projects.size == 1
        @project = @projects.first
      end
    elsif params[:project_id]
      @project = Project.visible.find_by_param(params[:project_id])
    end
  end

  def find_watchables
    @watchables = find_objects_from_params
    unless @watchables.present?
      render_404
    end
  end

  def set_watcher(watchables, user, watching)
    watchables.each do |watchable|
      watchable.set_watcher(user, watching)
    end
    respond_to do |format|
      format.html do
        text = watching ? 'Watcher added.' : 'Watcher removed.'
        redirect_to_referer_or do
          render(:html => text, :status => :ok, :layout => true)
        end
      end
      format.js do
        render(:partial => 'set_watcher',
               :locals => {:user => user, :watched => watchables})
      end
    end
  end

  # Returns a paginated array of users that can be added as watchers to the object(s).
  def users_for_new_watcher
    limit = WATCHER_USERS_PER_PAGE
    offset = params[:offset].to_i
    offset = 0 if offset < 0
    q = params[:q].to_s.strip

    valid_users, next_offset, more = scan_watcher_candidates(watcher_candidate_scope(q), offset, limit)

    @more_users_for_watcher = more
    @watcher_users_next_offset = next_offset
    valid_users
  end

  def watcher_candidate_scope(q)
    scope =
      if q.blank?
        if @project.present?
          @project.principals.assignable_watchers
        elsif @projects.present? && @projects.size > 1
          Principal.joins(:members).where(:members => {:project_id => @projects}).assignable_watchers.distinct
        else
          Principal.none
        end
      else
        Principal.assignable_watchers
      end

    if @watchables&.size == 1
      watcher_ids = @watchables.first.visible_watcher_users.map(&:id)
      scope = scope.where.not(:id => watcher_ids) if watcher_ids.present?
    end

    scope.sorted.like(q)
  end

  def scan_watcher_candidates(scope, offset, limit)
    valid_users = []
    current_offset = offset
    has_more = false

    while valid_users.size < limit
      batch = scope.offset(current_offset).limit(limit + 1).to_a
      has_more = batch.size > limit
      batch = batch.first(limit)
      break if batch.empty?

      batch.each_with_index do |user, idx|
        if @watchables.blank? || @watchables.all? {|w| w.valid_watcher?(user)}
          valid_users << user
          if valid_users.size == limit
            has_more ||= (idx + 1 < batch.size)
            current_offset += (idx + 1)
            break
          end
        end
      end

      break if valid_users.size == limit

      current_offset += batch.size
      break unless has_more
    end

    [valid_users, current_offset, has_more && (valid_users.size == limit)]
  end

  def users_for_mention
    users = []
    q = params[:q].to_s.strip

    scope = nil
    if params[:q].blank? && @project.present?
      scope = @project.principals.assignable_watchers.limit(100)
    else
      scope = Principal.assignable_watchers.limit(10)
    end
    # Exclude Group principal for now
    scope = scope.where(:type => ['User'])

    users = scope.sorted.like(params[:q]).to_a

    if @watchables && @watchables.size == 1
      object = @watchables.first
      if object.respond_to?(:visible?)
        users.reject! {|user| user.is_a?(User) && !object.visible?(user)}
      end
    end

    users
  end

  def format_users_json(users)
    users.map do |user|
      {
        'firstname' => user.firstname,
        'lastname' => user.lastname,
        'name' => user.name,
        'login' => user.login
      }
    end
  end

  def find_objects_from_params
    klass =
      begin
        Object.const_get(params[:object_type].camelcase)
      rescue
        nil
      end
    return unless klass && Class === klass # rubocop:disable Style/CaseEquality
    return unless klass < ApplicationRecord
    return unless klass < Redmine::Acts::Watchable::InstanceMethods

    scope = klass.where(:id => Array.wrap(params[:object_id])).order(:id)
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

  # Check permission for the watchable type for each watchable involved
  def authorize_for_watchable_type(action)
    if @watchables.any?{|watchable| !User.current.allowed_to?(:"#{action}_#{watchable.class.name.underscore}_watchers", watchable.project)}
      render_403
      return false
    else
      return true
    end
  end
end
