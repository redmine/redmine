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

class SysController < ActionController::Base
  include ActiveSupport::SecurityUtils

  before_action :check_enabled

  # Requests from repository WS clients don't contain CSRF tokens
  skip_before_action :verify_authenticity_token

  def projects
    p = Project.active.has_module(:repository).
          order("#{Project.table_name}.identifier").preload(:repository).to_a
    # extra_info attribute from repository breaks activeresource client
    render :json =>
              p.to_json(:only => [:id, :identifier, :name, :is_public, :status],
                        :include => {:repository => {:only => [:id, :url]}})
  end

  def create_project_repository
    project = Project.find(params[:id])
    if project.repository
      head :conflict
    else
      logger.info "Repository for #{project.name} was reported to be created by #{request.remote_ip}."
      repository = Repository.factory(params[:vendor])
      repository.safe_attributes = params[:repository]
      repository.project = project
      if repository.save
        render :json => {repository.class.name.underscore.tr('/', '-') => {:id => repository.id, :url => repository.url}}, :status => :created
      else
        head :unprocessable_content
      end
    end
  end

  def fetch_changesets
    projects = []
    scope = Project.active.has_module(:repository)
    if params[:id]
      project = nil
      if /^\d*$/.match?(params[:id].to_s)
        project = scope.find(params[:id])
      else
        project = scope.find_by_identifier(params[:id])
      end
      raise ActiveRecord::RecordNotFound unless project

      projects << project
    else
      projects = scope.to_a
    end
    projects.each do |project|
      project.repositories.each do |repository|
        repository.fetch_changesets
      end
    end
    head :ok
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  protected

  def check_enabled
    User.current = nil
    unless Setting.sys_api_enabled? && secure_compare(params[:key].to_s, Setting.sys_api_key.to_s)
      render :plain => 'Access denied. Repository management WS is disabled or key is invalid.', :status => :forbidden
      return false
    end
  end
end
