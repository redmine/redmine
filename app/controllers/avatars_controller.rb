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

class AvatarsController < ApplicationController
  layout :avatar_layout
  self.main_menu = false
  menu_item :users

  before_action :find_avatar, :only => :show
  before_action :find_user, :except => :show
  before_action :check_avatar_available, :except => :edit

  accept_api_auth :show

  def show
    # The original image is never served since it may contain metadata
    # such as the location where it was taken
    file = @avatar.thumbnail(:size => params[:size], :crop => true)
    unless file
      render_404
      return
    end

    expires_in 1.day, :public => !Setting.login_required?
    if stale?(:etag => file, :template => false)
      send_file(
        file,
        :filename => filename_for_content_disposition(@avatar.filename),
        :type => @avatar.content_type,
        :disposition => 'inline')
    end
  end

  def edit
  end

  def update
    file = params[:avatar]
    if !file.respond_to?(:original_filename)
      @user.errors.add(:avatar, :blank)
    elsif @user.update_avatar(file)
      flash[:notice] = l(:notice_successful_update)
      redirect_to @avatar_path
      return
    end

    render :edit, :status => :unprocessable_content
  end

  def destroy
    @user.delete_avatar
    flash[:notice] = l(:notice_successful_delete)
    redirect_to @avatar_path
  end

  private

  def find_avatar
    user = User.find_by(:id => params[:user_id])
    key = user&.avatar_key
    @avatar = user.avatar if key && ActiveSupport::SecurityUtils.secure_compare(key, params[:avatar_key])
    render_404 unless @avatar&.readable?
  end

  # /my/avatar is for the current user and /users/:user_id/avatar is for
  # administrators
  def find_user
    if params[:user_id]
      return unless require_admin

      @user = User.find_by(:id => params[:user_id])
      if @user
        @avatar_path = edit_user_avatar_path(@user)
      else
        render_404
      end
    elsif require_login
      @user = User.current
      @avatar_path = my_avatar_path
    end
  end

  def check_avatar_available
    render_404 unless User.avatar_available?
  end

  def avatar_layout
    params[:user_id] ? 'admin' : 'base'
  end
end
