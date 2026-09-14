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

class WebhooksController < ApplicationController
  self.main_menu = false

  before_action :require_login
  before_action :check_enabled_or_admin, only: [:edit, :update, :destroy]
  before_action :check_enabled, except: [:edit, :update, :destroy]
  before_action :authorize

  before_action :find_webhook, only: [:edit, :update, :destroy]

  require_sudo_mode :create, :update, :destroy

  def index
    @webhooks = webhooks.preload(:projects).order(:url)
  end

  def new
    @webhook = Webhook.new
    @webhook.safe_attributes = params[:webhook]
  end

  def edit
  end

  def create
    @webhook = webhooks.build
    @webhook.safe_attributes = params[:webhook]
    if @webhook.save
      redirect_back_or_default webhooks_path
    else
      render :new
    end
  end

  def update
    @webhook.safe_attributes = params[:webhook]
    if @webhook.save
      redirect_back_or_default webhooks_path
    else
      render :edit
    end
  end

  def destroy
    @webhook.destroy
    redirect_back_or_default webhooks_path
  end

  private

  def find_webhook
    @webhook = Webhook.editable.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def webhooks
    User.current.webhooks
  end

  def authorize
    deny_access unless User.current.allowed_to?(:use_webhooks, nil, global: true)
  end

  def check_enabled
    render_403 unless Webhook.enabled?
  end

  def check_enabled_or_admin
    render_403 unless Webhook.enabled? || User.current.admin?
  end
end
