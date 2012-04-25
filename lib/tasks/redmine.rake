# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
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
  namespace :attachments do
    desc 'Removes uploaded files left unattached after one day.'
    task :prune => :environment do
      Attachment.prune
    end
  end

  namespace :tokens do
    desc 'Removes expired tokens.'
    task :prune => :environment do
      Token.destroy_expired
    end
  end

  namespace :watchers do
    desc 'Removes watchers from what they can no longer view.'
    task :prune => :environment do
      Watcher.prune
    end
  end

  desc 'Fetch changesets from the repositories'
  task :fetch_changesets => :environment do
    Repository.fetch_changesets
  end

  desc 'Migrates and copies plugins assets.'
  task :plugins do
    Rake::Task["redmine:plugins:migrate"].invoke
    Rake::Task["redmine:plugins:assets"].invoke
  end

  namespace :plugins do
    desc 'Migrates installed plugins.'
    task :migrate => :environment do
      Redmine::Plugin.all.each do |plugin|
        puts "Migrating #{plugin.name}..."
        plugin.migrate
      end
    end

    desc 'Copies plugins assets into the public directory.'
    task :assets => :environment do
      Redmine::Plugin.all.each do |plugin|
        puts "Copying #{plugin.name} assets..."
        plugin.mirror_assets
      end
    end
  end
end
