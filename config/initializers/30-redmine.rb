# frozen_string_literal: true

require 'redmine/configuration'
require 'redmine/plugin_loader'

Rails.application.config.to_prepare do
  I18n::Backend::Simple.include(I18n::Backend::Pluralization)

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
  Doorkeeper.configure do
    orm :active_record

    # Issue access tokens with refresh token
    use_refresh_token

    # Authorization Code expiration time (default: 10 minutes).
    #
    # authorization_code_expires_in 10.minutes

    # Access token expiration time (default: 2 hours).
    # If you want to disable expiration, set this to `nil`.
    #
    # access_token_expires_in 2.hours

    # Hash access and refresh tokens before persisting them.
    # https://doorkeeper.gitbook.io/guides/security/token-and-application-secrets
    hash_token_secrets

    # Hash application secrets before persisting them.
    hash_application_secrets using: '::Doorkeeper::SecretStoring::BCrypt'

    # limit supported flows to Auth code
    grant_flows ['authorization_code']

    realm           Redmine::Info.app_name
    base_controller 'ApplicationController'
    default_scopes(*Redmine::AccessControl.public_permissions.map(&:name))
    optional_scopes(*(Redmine::AccessControl.permissions.map(&:name) << :admin))

    # Forbids creating/updating applications with arbitrary scopes that are
    # not in configuration, i.e. +default_scopes+ or +optional_scopes+.
    enforce_configured_scopes

    allow_token_introspection false

    # allow http loopback redirect URIs but require https for all others
    force_ssl_in_redirect_uri { |uri| !%w[localhost 127.0.0.1 web localohst:8080].include?(uri.host) }

    # Specify what redirect URI's you want to block during Application creation.
    forbid_redirect_uri { |uri| %w[data vbscript javascript].include?(uri.scheme.to_s.downcase) }

    resource_owner_authenticator do
      if require_login
        if Setting.rest_api_enabled?
          User.current
        else
          deny_access
        end
      end
    end

    admin_authenticator do |_routes|
      if !Setting.rest_api_enabled? || !User.current.admin?
        deny_access
      end
    end
  end

  # Use Redmine standard layouts and helpers for Doorkeeper OAuth2 screens
  Doorkeeper::ApplicationsController.layout "admin"
  Doorkeeper::ApplicationsController.main_menu = false
  Doorkeeper::AuthorizationsController.layout "base"
  Doorkeeper::AuthorizedApplicationsController.layout "base"
  Doorkeeper::AuthorizedApplicationsController.main_menu = false

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

  Doorkeeper::ApplicationsController.class_eval do
    require_sudo_mode :create, :show, :update, :destroy
  end

  Doorkeeper::AuthorizationsController.class_eval do
    require_sudo_mode :create, :destroy
  end
end

Rails.application.deprecators[:redmine] = ActiveSupport::Deprecation.new('7.0', 'Redmine')
