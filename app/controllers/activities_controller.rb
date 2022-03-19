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

class ActivitiesController < ApplicationController
  menu_item :activity
  before_action :find_optional_project_by_id, :authorize_global
  accept_atom_auth :index

  def index
    @days = Setting.activity_days_default.to_i

    if params[:from]
      begin; @date_to = params[:from].to_date + 1; rescue; end
    end

    @date_to ||= User.current.today + 1
    @date_from = @date_to - @days
    @with_subprojects = params[:with_subprojects].nil? ? Setting.display_subprojects_issues? : (params[:with_subprojects] == '1')
    if params[:user_id].present?
      @author = User.visible.active.find(params[:user_id])
    end

    @activity = Redmine::Activity::Fetcher.new(User.current, :project => @project,
                                                             :with_subprojects => @with_subprojects,
                                                             :author => @author)
    pref = User.current.pref
    @activity.scope_select {|t| !params["show_#{t}"].nil?}
    if @activity.scope.present?
      if params[:submit].present?
        pref.activity_scope = @activity.scope
        pref.save
      end
    else
      if @author.nil?
        scope = pref.activity_scope & @activity.event_types
        @activity.scope = scope.present? ? scope : :default
      else
        @activity.scope = :all
      end
    end

    events =
      if params[:format] == 'atom'
        @activity.events(nil, nil, :limit => Setting.feeds_limit.to_i)
      else
        @activity.events(@date_from, @date_to)
      end

    if events.empty? || stale?(:etag => [@activity.scope, @date_to, @date_from, @with_subprojects, @author, events.first, events.size, User.current, current_language])
      respond_to do |format|
        format.html do
          @events_by_day = events.group_by {|event| User.current.time_to_date(event.event_datetime)}
          render :layout => false if request.xhr?
        end
        format.atom do
          title = l(:label_activity)
          if @author
            title = @author.name
          elsif @activity.scope.size == 1
            title = l("label_#{@activity.scope.first.singularize}_plural")
          end
          render_feed(events, :title => "#{@project || Setting.app_title}: #{title}")
        end
      end
    end

  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
