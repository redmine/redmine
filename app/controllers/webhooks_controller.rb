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

  ADMIN_CUSTODY_ACTIONS = %w(edit update destroy).freeze

  before_action :require_login
  before_action :check_enabled
  before_action :authorize

  before_action :find_webhook, only: [:edit, :update, :destroy]

  require_sudo_mode :create, :update, :destroy

  helper_method :secret_hidden?

  def index
    @webhooks = webhooks.order(:url)
  end

  def new
    @webhook = Webhook.new
  end

  def edit
  end

  def create
    @webhook = webhooks.build(webhook_params)
    if @webhook.save
      redirect_back_or_default webhooks_path
    else
      render :new
    end
  end

  def update
    if @webhook.update(webhook_params)
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

  # True when the stored secret must not be disclosed to the current user
  def secret_hidden?
    @webhook&.persisted? && @webhook.user != User.current
  end

  def webhook_params
    attrs = params.require(:webhook).permit(:url, :secret, :active, events: [], project_ids: [])
    attrs.delete(:secret) if secret_hidden? && attrs[:secret].blank?
    attrs
  end

  def find_webhook
    @webhook = editable_webhooks.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def webhooks
    User.current.webhooks
  end

  # Administrators may edit any webhook, without ever becoming its owner
  def editable_webhooks
    User.current.admin? ? Webhook.all : webhooks
  end

  def authorize
    deny_access unless User.current.allowed_to?(:use_webhooks, nil, global: true)
  end

  def check_enabled
    return if Webhook.enabled?
    return if User.current.admin? && ADMIN_CUSTODY_ACTIONS.include?(action_name)

    render_403
  end
end
