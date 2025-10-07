# frozen_string_literal: true

class WebhooksController < ApplicationController
  self.main_menu = false

  before_action :require_login
  before_action :authorize

  before_action :find_webhook, only: [:edit, :update, :destroy]

  require_sudo_mode :create, :update, :destroy

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
      redirect_to webhooks_path
    else
      render :new
    end
  end

  def update
    if @webhook.update(webhook_params)
      redirect_to webhooks_path
    else
      render :edit
    end
  end

  def destroy
    @webhook.destroy
    redirect_to webhooks_path
  end

  private

  def webhook_params
    params.require(:webhook).permit(:url, :secret, :active, events: [], project_ids: [])
  end

  def find_webhook
    @webhook = webhooks.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def webhooks
    User.current.webhooks
  end

  def authorize
    deny_access unless User.current.allowed_to?(:use_webhooks, nil, global: true)
  end
end
