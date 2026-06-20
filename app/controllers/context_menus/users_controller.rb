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

module ContextMenus
  class UsersController < BaseController
    before_action :require_admin
    before_action :find_users

    def index
      @groups = Group.givable.sorted.to_a
      @common_group_ids = Group.givable.joins(:groups_users).where(groups_users: { user_id: @users.map(&:id) }).distinct.pluck(:id).to_set

      render_context_menu 'users'
    end

    private

    def find_users
      @users = User.where(id: params[:id] || params[:ids]).to_a
      raise ActiveRecord::RecordNotFound if @users.empty?

      if @users.size == 1
        @user = @users.first
      end
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end
end
