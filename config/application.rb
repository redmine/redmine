# frozen_string_literal: true

require File.expand_path('../boot', __FILE__)

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
require 'action_cable/engine'
# require 'sprockets/railtie'
require 'rails/test_unit/railtie'

Bundler.require(*Rails.groups)

module RedmineApp
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(#{config.root}/lib)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    config.active_record.store_full_sti_class = true
    config.active_record.default_timezone = :local

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    config.i18n.enforce_available_locales = true
    config.i18n.fallbacks = true
    config.i18n.default_locale = 'en'

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    config.action_mailer.perform_deliveries = false

    # Do not include all helpers
    config.action_controller.include_all_helpers = false

    # Since Redmine 4.0, boolean values are stored in sqlite3 databases as 1 and 0
    config.active_record.sqlite3.represent_boolean_as_integer = true

    # Sets the Content-Length header on responses with fixed-length bodies
    config.middleware.insert_before Rack::Sendfile, Rack::ContentLength

    # Verify validity of user sessions
    config.redmine_verify_sessions = true

    # Specific cache for search results, the default file store cache is not
    # a good option as it could grow fast. A memory store (32MB max) is used
    # as the default. If you're running multiple server processes, it's
    # recommended to switch to a shared cache store (eg. mem_cache_store).
    # See http://guides.rubyonrails.org/caching_with_rails.html#cache-stores
    # for more options (same options as config.cache_store).
    config.redmine_search_cache_store = :memory_store

    # Configure log level here so that additional environment file
    # can change it (environments/ENV.rb would take precedence over it)
    config.log_level = Rails.env.production? ? :info : :debug

    config.session_store :cookie_store,
      :key => '_redmine_session',
      :path => config.relative_url_root || '/'

    if File.exists?(File.join(File.dirname(__FILE__), 'additional_environment.rb'))
      instance_eval File.read(File.join(File.dirname(__FILE__), 'additional_environment.rb'))
    end
  end
end
