class EmailTemplatesController < ApplicationController
  unloadable

  def index
  end

  def show
  end

  def create
    declared_params = params.require(:email_template).permit(:domain)
    EmailTemplate.create(declared_params)
    redirect_to "/settings/plugin/mail_tracker"
  end

  def update
    declared_params = params.require(:email_template).permit(:title, :body)
    EmailTemplate.find(params[:id]).update(declared_params) if params[:id].present?
    redirect_to "/settings/plugin/mail_tracker"
  end

  def destroy
    template = EmailTemplate.find(params[:id])
    template.destroy
    redirect_to "/settings/plugin/mail_tracker"
  end
end