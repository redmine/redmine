I18n.default_locale = 'en'
I18n.backend = Redmine::I18n::Backend.new

require 'redmine'

# Load the secret token from the Redmine configuration file
secret = Redmine::Configuration['secret_token']
if secret.present?
  RedmineApp::Application.config.secret_token = secret
end

if Object.const_defined?(:OpenIdAuthentication)
  openid_authentication_store = Redmine::Configuration['openid_authentication_store']
  OpenIdAuthentication.store =
    openid_authentication_store.present? ?
      openid_authentication_store : :memory   
end

Redmine::Plugin.load
unless Redmine::Configuration['mirror_plugins_assets_on_startup'] == false
  Redmine::Plugin.mirror_assets
end
