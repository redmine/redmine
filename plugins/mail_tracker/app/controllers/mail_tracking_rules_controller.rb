class MailTrackingRulesController < ApplicationController
  unloadable
  def index

  end

  def show
    # @rules = MailTrackingRule.all
    # @host = MailSource.last
  end


  def add_rule
    empty = MailTrackingRule.new(login_name: params[:user_id])
    empty.save!
    render :nothing => true, :status => 200, :content_type => 'text/html'
  end

  def destroy
    rule = MailTrackingRule.find(params[:id]) if params[:id].present?
    rule.destroy!
    render :nothing => true, :status => 200, :content_type => 'text/html'
  end


  def update
    declared_params = params.require(:mail_tracking_rule).permit(:mail_part, :includes, :tracker_name, :assigned_group_id, :assigned_project_id, :end_duration, :priority)
    MailTrackingRule.find(params[:id]).update(declared_params) if params[:id].present?
    redirect_to edit_user_url(id: params[:user][:id])
  end


end