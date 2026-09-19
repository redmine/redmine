# frozen_string_literal: true

class DestroyProjectsJob < ApplicationJob
  include Redmine::I18n

  def self.schedule(projects_to_delete, user: User.current)
    Project.mark_for_deletion(projects_to_delete)
    perform_later(projects_to_delete.map(&:id), user.id, user.remote_ip)
  end

  def perform(project_ids, user_id, remote_ip)
    user = User.active.find_by_id(user_id)
    unless user&.admin?
      info "[DestroyProjectsJob] --- User check failed: User #{user_id} triggering projects destroy does not exist anymore or isn't admin/active."
      return
    end

    project_ids.each do |project_id|
      DestroyProjectJob.perform_now(project_id, user_id, remote_ip)
    end
  end

  private

  def info(*msg)
    Rails.logger.info(*msg)
  end
end
