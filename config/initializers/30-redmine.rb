# frozen_string_literal: true

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
  OpenIdAuthentication.store = openid_authentication_store.presence || :memory
end

Redmine::Plugin.load

plugin_assets_dirs = {}
Redmine::Plugin.all.each do |plugin|
  plugin_assets_dirs[plugin.assets_directory] = ["*"]
end
plugin_assets_reloader = ActiveSupport::FileUpdateChecker.new([], plugin_assets_dirs) do
  Redmine::Plugin.mirror_assets
end
Rails.application.reloaders << plugin_assets_reloader
unless Redmine::Configuration['mirror_plugins_assets_on_startup'] == false
  plugin_assets_reloader.execute
end

Rails.application.config.to_prepare do
  Redmine::FieldFormat::RecordList.subclasses.each do |klass|
    klass.instance.reset_target_class
  end

  plugin_assets_reloader.execute_if_updated
end
