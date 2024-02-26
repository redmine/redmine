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

class PreviewsController < ApplicationController
  before_action :find_project, :except => :text
  before_action :find_attachments

  def issue
    @issue = Issue.visible.find_by_id(params[:issue_id]) unless params[:issue_id].blank?
    if @issue
      @previewed = @issue
    end
    @text = params[:text] ? params[:text] : nil
    render :partial => 'common/preview'
  end

  def news
    if params[:id].present? && news = News.visible.find_by_id(params[:id])
      @previewed = news
    end
    @text = params[:text] ? params[:text] : nil
    render :partial => 'common/preview'
  end

  def text
    @text = params[:text] ? params[:text] : nil
    render :partial => 'common/preview'
  end

  private

  def find_project
    project_id = (params[:issue] && params[:issue][:project_id]) || params[:project_id]
    @project = Project.find(project_id)
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
