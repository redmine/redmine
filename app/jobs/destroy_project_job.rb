# frozen_string_literal: true

class DestroyProjectJob < ApplicationJob
  include Redmine::I18n

  def self.schedule(project, user: User.current)
    # make the project (and any children) disappear immediately
    project.self_and_descendants.update_all status: Project::STATUS_SCHEDULED_FOR_DELETION
    perform_later project.id, user.id, user.remote_ip
  end

  def perform(project_id, user_id, remote_ip)
    user_current_was = User.current

    unless @user = User.active.find_by_id(user_id)
      info "User check failed: User #{user_id} triggering project destroy does not exist anymore or isn't active."
      return
    end
    @user.remote_ip = remote_ip
    User.current = @user
    set_language_if_valid @user.language || Setting.default_language

    unless @project = Project.find_by_id(project_id)
      info "Project check failed: Project has already been deleted."
      return
    end

    unless @project.deletable?
      info "Project check failed: User #{user_id} lacks permissions."
      return
    end

    message = if @project.descendants.any?
                :mail_destroy_project_with_subprojects_successful
              else
                :mail_destroy_project_successful
              end
    delete_project ? success(message) : failure
  ensure
    User.current = user_current_was
    info "End destroy project"
  end

  private

  def delete_project
    info "Starting with project deletion"
    return !!@project.destroy
  rescue
    info "Error while deleting project: #{$!}"
    false
  end

  def success(message)
    Mailer.deliver_security_notification(
      @user, @user,
      message: message,
      value: @project.name,
      url: {controller: 'admin', action: 'projects'},
      title: :label_project_plural
    )
  end

  def failure
    Mailer.deliver_security_notification(
      @user, @user,
      message: :mail_destroy_project_failed,
      value: @project.name,
      url: {controller: 'admin', action: 'projects'},
      title: :label_project_plural
    )
  end

  def info(msg)
    Rails.logger.info("[DestroyProjectJob] --- #{msg}")
  end
end
