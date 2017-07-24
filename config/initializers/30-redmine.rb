I18n.default_locale = 'en'
I18n.backend = Redmine::I18n::Backend.new
# Forces I18n to load available locales from the backend
I18n.config.available_locales = nil

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

Rails.application.config.to_prepare do
  Redmine::FieldFormat::RecordList.subclasses.each do |klass|
    klass.instance.reset_target_class
  end
end
