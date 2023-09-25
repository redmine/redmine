class MailSourcesController < ApplicationController
  unloadable
  # protect_from_forgery with: :null_session, only: [:activate]
  skip_before_action :verify_authenticity_token, :check_if_login_required, only: [:activate, :activate_oauth]


  def index

  end

  def show

  end

  def add_new
    MailSource.create
    redirect_to "/settings/plugin/mail_tracker"
  end

  def activate_oauth
    # render status: 200
    oauth_params = params.permit(:id_token, :access_token, :code)
    email = JSON.parse(Base64.decode64(oauth_params['id_token'].split('.')[1]))['email']
    mail_source = MailSource.find_by(email_address: email)
    mail_source.update!(azure_code: oauth_params['code'], id_token: oauth_params['id_token'], enabled_sync: true) if oauth_params['code'].present?

    redirect_to "/settings/plugin/mail_tracker"
  end

  def activate
    # render status: 200
    record = MailSource.find(params[:id])
    record.update!(enabled_sync: true)
    redirect_to "/settings/plugin/mail_tracker"
  end

  def deactivate
    record = MailSource.find(params[:id])
    record.update(enabled_sync: false)
    redirect_to "/settings/plugin/mail_tracker"
  end

  def update
    declared_params = params.require(:mail_source).permit(:host, :username, :password, :oauth_enabled, :application_id, :default_project_id, :no_rules_project_id, :default_user_id, :delivery_port, :receive_protocol, :receive_port, :use_ssl, :use_tls, :receive_host, :email_address, :reply_cut_from, :projects_to_sync => [])
    declared_params["projects_to_sync"] = declared_params["projects_to_sync"].present? ? declared_params["projects_to_sync"].reject(&:empty?).to_json : [].to_json
    MailSource.find(params[:id]).update(declared_params) if params[:id].present?
    redirect_to "/settings/plugin/mail_tracker"
  end

  def destroy
    template = MailSource.find(params[:id])
    template.destroy
    redirect_to "/settings/plugin/mail_tracker"
  end
end