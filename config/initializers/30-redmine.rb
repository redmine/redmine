# frozen_string_literal: true

require 'redmine/configuration'
require 'redmine/plugin_loader'

Rails.application.config.to_prepare do
  I18n.backend = Redmine::I18n::Backend.new
  # Forces I18n to load available locales from the backend
  I18n.config.available_locales = nil

  Redmine::Preparation.prepare
end

# Load the secret token from the Redmine configuration file
secret = Redmine::Configuration['secret_token']
if secret.present?
  RedmineApp::Application.config.secret_token = secret
end

Redmine::PluginLoader.load
plugin_assets_reloader = Redmine::PluginLoader.create_assets_reloader

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
