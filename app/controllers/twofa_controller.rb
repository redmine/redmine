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

class TwofaController < ApplicationController
  include TwofaHelper

  self.main_menu = false

  before_action :require_login
  before_action :require_admin, only: :admin_deactivate

  before_action :require_active_twofa

  require_sudo_mode :activate_init, :deactivate_init

  skip_before_action :check_twofa_activation, only: [:select_scheme, :activate_init, :activate_confirm, :activate]

  def select_scheme
    @user = User.current
  end

  before_action :activate_setup, only: [:activate_init, :activate_confirm, :activate]

  def activate_init
    init_twofa_pairing_and_send_code_for(@twofa)
  end

  def activate_confirm
    @twofa_view = @twofa.init_pairing_view_variables
  end

  def activate
    if @twofa.confirm_pairing!(params[:twofa_code].to_s)
      # The session token was destroyed by the twofa pairing, generate a new one
      session[:tk] = @user.generate_session_token
      flash[:notice] = l('twofa_activated', bc_path: my_twofa_backup_codes_init_path)
      redirect_to my_account_path
    else
      flash[:error] = l('twofa_invalid_code')
      redirect_to action: :activate_confirm, scheme: @twofa.scheme_name
    end
  end

  before_action :deactivate_setup, only: [:deactivate_init, :deactivate_confirm, :deactivate]

  def deactivate_init
    if @twofa.send_code(controller: 'twofa', action: 'deactivate')
      flash[:notice] = l('twofa_code_sent')
    end
    redirect_to action: :deactivate_confirm, scheme: @twofa.scheme_name
  end

  def deactivate_confirm
    @twofa_view = @twofa.otp_confirm_view_variables
  end

  def deactivate
    if @twofa.destroy_pairing!(params[:twofa_code].to_s)
      flash[:notice] = l('twofa_deactivated')
      redirect_to my_account_path
    else
      flash[:error] = l('twofa_invalid_code')
      redirect_to action: :deactivate_confirm, scheme: @twofa.scheme_name
    end
  end

  def admin_deactivate
    @user = User.find(params[:user_id])
    # do not allow administrators to unpair 2FA without confirmation for themselves
    if @user == User.current
      render_403
      return false
    end

    twofa = Redmine::Twofa.for_user(@user)
    twofa.destroy_pairing_without_verify!
    flash[:notice] = l('twofa_deactivated')
    redirect_to edit_user_path(@user)
  end

  private

  def activate_setup
    twofa_scheme = Redmine::Twofa.for_twofa_scheme(params[:scheme].to_s)

    if twofa_scheme.blank?
      redirect_to my_account_path
      return
    end
    @user = User.current
    @twofa = twofa_scheme.new(@user)
  end

  def deactivate_setup
    @user = User.current
    @twofa = Redmine::Twofa.for_user(@user)
    if params[:scheme].to_s != @twofa.scheme_name
      redirect_to my_account_path
    end
  end
end
