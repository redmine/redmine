# frozen_string_literal: true

#
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
#
class Oauth2ApplicationsController < Doorkeeper::ApplicationsController
  private

  def application_params
    params[:doorkeeper_application] ||= {}
    params[:doorkeeper_application][:scopes] ||= []

    scopes = Redmine::AccessControl.public_permissions.map{|p| p.name.to_s}

    if params[:doorkeeper_application][:scopes].is_a?(Array)
      scopes |= params[:doorkeeper_application][:scopes]
    else
      scopes |= params[:doorkeeper_application][:scopes].split(/\s+/)
    end
    params[:doorkeeper_application][:scopes] = scopes.join(' ')
    super
  end
end
