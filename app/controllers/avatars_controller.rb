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
  before_action :find_avatar
  before_action :check_avatar_available

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

  private

  def find_avatar
    user = User.find_by(:id => params[:user_id])
    key = user&.avatar_key
    @avatar = user.avatar if key && ActiveSupport::SecurityUtils.secure_compare(key, params[:avatar_key])
    render_404 unless @avatar&.readable?
  end

  def check_avatar_available
    render_404 unless User.avatar_available?
  end
end
