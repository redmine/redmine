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

class TwofaBackupCodesController < ApplicationController
  include TwofaHelper

  self.main_menu = false

  before_action :require_login, :require_active_twofa

  before_action :twofa_setup

  require_sudo_mode :init

  def init
    if @twofa.send_code(controller: 'twofa_backup_codes', action: 'create')
      flash[:notice] = l('twofa_code_sent')
    end
    redirect_to action: 'confirm'
  end

  def confirm
    @twofa_view = @twofa.otp_confirm_view_variables
  end

  def create
    if @twofa.verify!(params[:twofa_code].to_s)
      if time = @twofa.backup_codes.map(&:created_on).max
        flash[:warning] = t('twofa_warning_backup_codes_generated_invalidated', time: format_time(time))
      else
        flash[:notice] = t('twofa_notice_backup_codes_generated')
      end
      tokens = @twofa.init_backup_codes!
      flash[:twofa_backup_token_ids] = tokens.collect(&:id)
      redirect_to action: 'show'
    else
      flash[:error] = l('twofa_invalid_code')
      redirect_to action: 'confirm'
    end
  end

  def show
    # make sure we get only the codes that we should show
    tokens = @twofa.backup_codes.where(id: flash[:twofa_backup_token_ids])
    # Redmine will show all flash contents at the top of the rendered html
    # page, so we need to explicitely delete this here
    flash.delete(:twofa_backup_token_ids)

    if tokens.present? && (@created_at = tokens.collect(&:created_on).max) > 5.minutes.ago
      @backup_codes = tokens.collect(&:value)
    else
      flash[:warning] = l('twofa_backup_codes_already_shown', bc_path: my_twofa_backup_codes_init_path)
      redirect_to controller: 'my', action: 'account'
    end
  end

  private

  def twofa_setup
    @user = User.current
    @twofa = Redmine::Twofa.for_user(@user)
  end
end
