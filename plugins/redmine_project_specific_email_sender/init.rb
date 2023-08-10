require 'redmine'

Redmine::Plugin.register :redmine_project_specific_email_sender do
  name 'Redmine Project Specific Email Sender plugin'
  author 'Adam Walters'
  description "This is a plugin for Redmine which allows each project to have it's own sender email address for project related, outbound emails"
  version '1.0.0'

  permission :edit_project_email, {:projects => :settings, :project_emails => [:update, :destroy, :watchers]}
end

prepare_block = Proc.new do
  Project.send(:prepend, RedmineProjectSpecificEmailSender::ProjectPatch)
  Mailer.send(:prepend, RedmineProjectSpecificEmailSender::MailerPatch)
  ProjectsHelper.send(:prepend, RedmineProjectSpecificEmailSender::ProjectsHelperPatch)
end

# if Rails.env.development?
#   ActionDispatch::Reloader.to_prepare { prepare_block.call }
# else
  prepare_block.call
# end
ActionMailer::Base.register_interceptor(RedmineProjectSpecificEmailSender::Interceptor)
