# Redmine - project management software
# Copyright (C) 2006-2014  Jean-Philippe Lang
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

class WelcomeController < ApplicationController
  caches_action :robots
  
  include ApplicationHelper

  def index
    @user = User.current
    @news = News.latest User.current
    @projects = Project.latest User.current
    @memberships = @user.memberships.all(:conditions => Project.visible_condition(User.current))
    events = Redmine::Activity::Fetcher.new(User.current, :author => @user).events(nil, nil, :limit => 10)
    @events_by_day = events.group_by(&:event_date)
    
    if !User.current.logged?
      @galleryImages = getGalleryImages(@projects)
    end  
      
  end

  def getGalleryImages(projects)
    scope = Project
    scope = scope.active
    galleryProjects = scope.visible.order('lft').all
    
    galleryImages=[]  
    for p in galleryProjects
      if isEndorsedOrBestPractice?(p)
        projectDescription = p.description
        firstLine = projectDescription.lines.first.chomp
        #This is for textile
        #if (firstLine.start_with?("!") and firstLine.end_with?("!"))
        #This is for markdown
        if (firstLine.start_with?("![]"))
          galleryImages.push({:image => firstLine, :project => p})
        end  
      end
    end
    return galleryImages
  end
  
  def robots
    @projects = Project.all_public.active
    render :layout => false, :content_type => 'text/plain'
  end
end
