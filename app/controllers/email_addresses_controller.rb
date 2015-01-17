# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

class EmailAddressesController < ApplicationController
  before_filter :find_user, :require_admin_or_current_user
  before_filter :find_email_address, :only => [:update, :destroy]

  def index
    @addresses = @user.email_addresses.order(:id).where(:is_default => false).to_a
    @address ||= EmailAddress.new
  end

  def create
    saved = false
    if @user.email_addresses.count <= Setting.max_additional_emails.to_i
      @address = EmailAddress.new(:user => @user, :is_default => false)
      attrs = params[:email_address]
      if attrs.is_a?(Hash)
        @address.address = attrs[:address].to_s
      end
      saved = @address.save
    end

    respond_to do |format|
      format.html {
        if saved
          redirect_to user_email_addresses_path(@user)
        else
          index
          render :action => 'index'
        end
      }
      format.js {
        @address = nil if saved
        index
        render :action => 'index'
      }
    end
  end

  def update
    if params[:notify].present?
      @address.notify = params[:notify].to_s
    end
    @address.save

    respond_to do |format|
      format.html {
        redirect_to user_email_addresses_path(@user)
      }
      format.js {
        @address = nil
        index
        render :action => 'index'
      }
    end
  end

  def destroy
    @address.destroy

    respond_to do |format|
      format.html {
        redirect_to user_email_addresses_path(@user)
      }
      format.js {
        @address = nil
        index
        render :action => 'index'
      }
    end
  end

  private

  def find_user
    @user = User.find(params[:user_id])
  end

  def find_email_address
    @address = @user.email_addresses.where(:is_default => false).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def require_admin_or_current_user
    unless @user == User.current
      require_admin
    end
  end
end
