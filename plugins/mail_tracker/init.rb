Redmine::Plugin.register :mail_tracker do
  name 'Mail Tracker plugin'
  author 'Wisemonks'
  author_url 'https://wisemonks.com'
  description 'Real time email fetch for issue coordination'
  version '1.0.3'
  settings :default => {
    :allowed_users => User.table_exists? ? User.where(["users.login IS NOT NULL AND users.login <> ''"]).collect {|x| x.id.to_s} : [] },
    :partial => 'settings/mail_tracker_settings'
end

Proc.new do
  Group.send(:include, GroupUpdate)
  Issue.send(:include, IssuePatch)
  IssueQuery.send(:include, QueryTracker)
  Project.send(:include, ProjectPatch)
  ReportsController.send(:include, ReportsControllerPatch)
  WatchersController.send(:include, WatchersControllerPatch)
end.call