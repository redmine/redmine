I18n.default_locale = 'en'
# Adds fallback to default locale for untranslated strings
I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)

require 'redmine'

# Load the secret token from the Redmine configuration file
secret = Redmine::Configuration['secret_token']
if secret.present?
  RedmineApp::Application.config.secret_token = secret
end

Redmine::Plugin.load
unless Redmine::Configuration['mirror_plugins_assets_on_startup'] == false
  Redmine::Plugin.mirror_assets
end
