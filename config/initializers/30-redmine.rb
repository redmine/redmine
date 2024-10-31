# frozen_string_literal: true

require 'redmine/configuration'
require 'redmine/plugin_loader'

Rails.application.config.to_prepare do
  I18n.backend = Redmine::I18n::Backend.new
  # Forces I18n to load available locales from the backend
  I18n.config.available_locales = nil

  # Use Nokogiri as XML backend instead of Rexml
  ActiveSupport::XmlMini.backend = 'Nokogiri'

  Redmine::Preparation.prepare
end

# Load the secret token from the Redmine configuration file
secret = Redmine::Configuration['secret_token']
if secret.present?
  RedmineApp::Application.config.secret_token = secret
end

Redmine::PluginLoader.load

Rails.application.config.to_prepare do
  default_paths = []
  default_paths << Rails.root.join("app/assets/javascripts")
  default_paths << Rails.root.join("app/assets/images")
  default_paths << Rails.root.join("app/assets/stylesheets")
  Rails.application.config.assets.redmine_default_asset_path = Redmine::AssetPath.new(Rails.root.join('app/assets'), default_paths)

  Redmine::FieldFormat::RecordList.subclasses.each do |klass|
    klass.instance.reset_target_class
  end

  Redmine::Plugin.all.each do |plugin|
    paths = plugin.asset_paths
    Rails.application.config.assets.redmine_extension_paths << paths if paths.present?
  end

  Redmine::Themes.themes.each do |theme|
    paths = theme.asset_paths
    Rails.application.config.assets.redmine_extension_paths << paths if paths.present?
  end
end

Rails.application.deprecators[:redmine] = ActiveSupport::Deprecation.new('7.0', 'Redmine')
