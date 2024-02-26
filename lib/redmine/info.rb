# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module Redmine
  module Info
    class << self
      def app_name; 'Redmine' end
      def url; 'https://www.redmine.org/' end
      def help_url; 'https://www.redmine.org/guide' end
      def versioned_name; "#{app_name} #{Redmine::VERSION}" end

      def environment
        s = +"Environment:\n"
        s << [
          ["Redmine version", Redmine::VERSION],
          ["Ruby version", "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]"],
          ["Rails version", Rails::VERSION::STRING],
          ["Environment", Rails.env],
          ["Database adapter", ActiveRecord::Base.connection.adapter_name],
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
