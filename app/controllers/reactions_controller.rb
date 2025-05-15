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

class ReactionsController < ApplicationController
  before_action :require_login

  before_action :check_enabled
  before_action :set_object, :authorize_reactable

  def create
    respond_to do |format|
      format.js do
        @object.reactions.find_or_create_by!(user: User.current)
      end
      format.any { head :not_found }
    end
  end

  def destroy
    respond_to do |format|
      format.js do
        reaction = @object.reactions.by(User.current).find_by(id: params[:id])
        reaction&.destroy
      end
      format.any { head :not_found }
    end
  end

  private

  def check_enabled
    render_403 unless Setting.reactions_enabled?
  end

  def set_object
    object_type = params[:object_type]

    unless Redmine::Reaction::REACTABLE_TYPES.include?(object_type)
      render_403
      return
    end

    @object = object_type.constantize.find(params[:object_id])
  end

  def authorize_reactable
    render_403 unless Redmine::Reaction.editable?(@object, User.current)
  end
end
