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

class FaviconsController < ApplicationController
  # The favicon is also shown on the login page
  skip_before_action :check_if_login_required, :check_password_change, :check_twofa_activation

  def show
    favicon = Setting.favicon
    if favicon['digest'] != params[:digest]
      render_404
      return
    end

    # The URL changes whenever the favicon is replaced
    expires_in 1.year, :public => true, :immutable => true
    send_data Base64.decode64(favicon['data']), :type => favicon['content_type'], :disposition => 'inline'
  end
end
