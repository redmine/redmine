Redmine::Plugin.register :mail_tracker do
  name 'Mail Tracker plugin'
  author 'Wisemonks'
  author_url 'https://wisemonks.com'
  description 'Real time email fetch for issue coordination'
  version '1.0.3'
  settings :default => {
    :allowed_users => User.table_exists? ? User.where(["users.login IS NOT NULL AND users.login <> ''"]).collect {|x| x.id.to_s} : [] },
    :partial => 'settings/mail_tracker_settings'
  project_module :issue_tracking do
    permission :edit_after_close_issues, {:issues => [:edit, :update, :bulk_edit, :bulk_update], :journals => [:new], :attachments => :upload}
    permission :view_only_watcher_issues, {:issues => [:edit, :update, :bulk_edit, :bulk_update], :journals => [:new], :attachments => :upload}
  end
  project_module :project_management do
    permission :edit_project_email, {:projects => :settings, :project_emails => [:update, :destroy, :watchers]}
  end
end

Proc.new do
  Journal.send(:include, JournalPatch)
  Group.send(:include, GroupUpdate)
  Issue.send(:include, IssuePatch)
  IssueQuery.send(:include, QueryTracker)
  Project.send(:include, ProjectPatch)
  ReportsController.send(:include, ReportsControllerPatch)
  WatchersController.send(:include, WatchersControllerPatch)
  ApplicationHelper.send(:include, ApplicationHelperPatch)
  SettingsHelper.send(:include, SettingsHelperPatch)
  Setting.send(:include, SettingPatch)
end.call