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

namespace :redmine do
  namespace :mermaid do
    desc <<~END_DESC
      Installs Mermaid.js so that Mermaid code blocks are rendered as diagrams.

      Mermaid.js is not bundled with Redmine. This task downloads the mermaid
      npm package from registry.npmjs.org, verifies its checksum and places
      dist/mermaid.min.js into vendor/javascript. It installs the specific
      version that this Redmine release has been tested with, which is not
      necessarily the latest version of Mermaid.js.
      Set FILE to install from a local copy of the npm tarball instead,
      e.g. on a server without internet access.
      redmine:mermaid:status shows the version and the URL of the package.
      Restart Redmine after installing.

      Examples:
        bin/rails redmine:mermaid:install RAILS_ENV="production"
        bin/rails redmine:mermaid:install FILE=/path/to/mermaid-X.Y.Z.tgz RAILS_ENV="production"
    END_DESC
    task :install => :environment do
      begin
        path = Redmine::Mermaid.install(source: ENV['FILE'].presence)
      rescue Redmine::Mermaid::Error => e
        abort "Mermaid.js installation failed: #{e.message}"
      end
      puts "Mermaid.js #{Redmine::Mermaid::VERSION} installed to #{path}."
      puts
      puts "Restart Redmine to enable diagram rendering. " \
           "If automatic asset compilation is disabled, run `bin/rails assets:precompile` first."
    end

    desc 'Removes the installed Mermaid.js.'
    task :uninstall => :environment do
      Redmine::Mermaid.uninstall
      puts "Mermaid.js removed. Restart Redmine to apply the change."
    end

    desc 'Shows the installation status of Mermaid.js.'
    task :status => :environment do
      if Redmine::Mermaid.available?
        version = Redmine::Mermaid.installed_version || '(unknown version)'
        puts "Mermaid.js #{version} is installed at #{Redmine::Mermaid.path}."
      else
        puts "Mermaid.js is not installed. Redmine looks for it at #{Redmine::Mermaid.path}"
      end
      # Nothing to suggest when the version installed by default is in place.
      unless Redmine::Mermaid.installed_version == Redmine::Mermaid::VERSION
        puts
        puts "Running `bin/rails redmine:mermaid:install` installs Mermaid.js #{Redmine::Mermaid::VERSION} " \
             "from #{Redmine::Mermaid::TARBALL_URL}"
      end
    end
  end
end
