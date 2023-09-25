class ProjectEmailsController < ApplicationController
  unloadable

  after_action :load_project, :authorize

  def update
    url = project_settings_tab_url

    @project.email = params[:email]
    @project.host_name = params[:host_name]
    @project.emails_info = params[:emails_info]
    @project.emails_header = params[:emails_header]
    @project.emails_footer = params[:emails_footer]

    if @project.project_email.save
      flash[:notice] = l(:notice_successful_update)
    else
      flash[:error] = @project.project_email.errors.full_messages.join("<br/>")
      url[:email] = params[:email]
    end
    redirect_to url
  end

  def destroy
    @project.project_email.destroy if @project.project_email
    @project.reload

    redirect_to project_settings_tab_url, :notice => l(:notice_email_reset)
  end

  def watchers
    url = project_settings_tab_url
    @project.watcher_group_ids = params[:watcher_group_ids]

    if @project.save
      flash[:notice] = l(:notice_successful_update)
    else
      flash[:error] = @project.errors.full_messages.join("<br/>")
    end

    redirect_to url
  end

  private

  def load_project
    @project = Project.find(params[:project_id])
  end

  def project_settings_tab_url
    { :controller => 'projects', :action => 'settings',
      :id => @project, :tab => 'outbound_email' }
  end
end
