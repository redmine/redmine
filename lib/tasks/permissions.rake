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
  desc "List all permissions and the actions registered with them"
  task :permissions => :environment do
    puts "Permission Name - controller/action pairs"
    Redmine::AccessControl.permissions.sort_by {|p| p.name.to_s}.each do |permission|
      puts ":#{permission.name} - #{permission.actions.join(', ')}"
    end
  end
end
