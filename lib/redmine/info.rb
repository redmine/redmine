# frozen_string_literal: true

module Redmine
  module Info
    class << self
      def app_name; 'Redmine' end
      def url; 'https://www.redmine.org/' end
      def help_url; 'https://www.redmine.org/guide' end
      def versioned_name; "#{app_name} #{Redmine::VERSION}" end

      def database_server
        db_connection = ActiveRecord::Base.connection
        adapter = db_connection.adapter_name.downcase
        if adapter.include?('postgresql')
          db_connection.execute("SELECT version()").first[0]
        elsif adapter.include?('mysql')
          "MySQL #{db_connection.execute('SELECT VERSION()').first[0]}"
        else
          'unknown'
        end
      end

      def web_server
        if defined?(Puma::Const::PUMA_VERSION)
          "Puma #{Puma::Const::PUMA_VERSION}"
        else
          'unknown'
        end
      end

      def session_store
        if Rails.application.config.session_store.name == "ActionDispatch::Session::RedisStore"
          options = Rails.application.config.session_options[:servers].first
          version = Redis.new(options).info['redis_version']
          "Redis #{version}"
        else
          'unknown'
        end
      end

      def environment
        s = +"Environment:\n"
        s << [
          ["Redmine version", Redmine::VERSION],
          ["Ruby version", "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]"],
          ["Rails version", Rails::VERSION::STRING],
          ["Environment", Rails.env],
          ["Database adapter", ActiveRecord::Base.connection.adapter_name],
          ["Database server", database_server],
          ["Web server", web_server],
          ["Session store", session_store],
          ["Cache store", Rails.cache.class.name],
          ["Mailer queue", ActionMailer::MailDeliveryJob.queue_adapter.class.name],
          ["Mailer delivery", ActionMailer::Base.delivery_method]
        ].map {|info| "  %-30s %s" % info}.join("\n") + "\n"

        theme_string = ''
        theme_string += (Setting.ui_theme.blank? ? 'Default' : Setting.ui_theme.capitalize)
        unless Setting.ui_theme.blank? ||
          Redmine::Themes.theme(Setting.ui_theme).nil? ||
          !Redmine::Themes.theme(Setting.ui_theme).javascripts.include?('theme')
          theme_string += ' (includes JavaScript)'
        end

        s << "Redmine settings:\n"
        s << [
          ["Redmine theme", theme_string]
        ].map {|settings| "  %-30s %s" % settings}.join("\n") + "\n"

        s << "SCM:\n"
        Redmine::Scm::Base.all.each do |scm|
          scm_class = "Repository::#{scm}".constantize
          if scm_class.scm_available
            s << "  %-30s %s\n" % [scm, scm_class.scm_version_string]
          end
        end

        s << "Redmine plugins:\n"
        plugins = Redmine::Plugin.all
        if plugins.any?
          s << plugins.map {|plugin| "  %-30s %s" % [plugin.id.to_s, plugin.version.to_s]}.join("\n")
        else
          s << "  no plugin installed"
        end
      end
    end
  end
end
