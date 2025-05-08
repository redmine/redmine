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

def deprecated_task(name, new_name)
  task name=>new_name do
    $stderr.puts "\nNote: The rake task #{name} has been deprecated, please use the replacement version #{new_name}"
  end
end

deprecated_task :load_default_data, "redmine:load_default_data"
deprecated_task :migrate_from_mantis, "redmine:migrate_from_mantis"
deprecated_task :migrate_from_trac, "redmine:migrate_from_trac"
deprecated_task "db:migrate_plugins", "redmine:plugins:migrate"
deprecated_task "db:migrate:plugin", "redmine:plugins:migrate"
deprecated_task :generate_session_store, :generate_secret_token
deprecated_task "test:rdm_routing", "test:routing"
