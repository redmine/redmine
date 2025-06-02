require 'redmine'

Redmine::Plugin.register :zendesk_updater do
  name 'Zendesk Updater'
  author 'Hillman'
  description 'Updates Zendesk tickets when Redmine issues are created or updated'
  version '1.0.0'
  url 'https://github.com/yourusername/zendesk_updater'
  author_url 'https://github.com/yourusername'

  requires_redmine version_or_higher: '4.0.0'
end

require_relative 'lib/zendesk_updater/issue_callbacks'
require_relative 'lib/zendesk_updater/journal_callbacks'
require_relative 'lib/zendesk_updater/lambda_client'

unless Issue.included_modules.include?(ZendeskUpdater::IssueCallbacks)
  Issue.include(ZendeskUpdater::IssueCallbacks)
end

unless Journal.included_modules.include?(ZendeskUpdater::JournalCallbacks)
  Journal.include(ZendeskUpdater::JournalCallbacks)
end