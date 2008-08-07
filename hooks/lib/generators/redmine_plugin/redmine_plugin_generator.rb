# redMine - project management software
# Copyright (C) 2006-2008  Jean-Philippe Lang
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

class RedminePluginGenerator < Rails::Generator::NamedBase
  attr_reader :plugin_path, :plugin_name
  
  def initialize(runtime_args, runtime_options = {})
    super
    @plugin_name = "redmine_#{file_name.underscore}"
    @plugin_path = "vendor/plugins/#{plugin_name}"
  end
  
  def manifest
    record do |m|
      m.directory "#{plugin_path}/app/controllers"
      m.directory "#{plugin_path}/app/helpers"
      m.directory "#{plugin_path}/app/models"
      m.directory "#{plugin_path}/app/views"
      m.directory "#{plugin_path}/db/migrate"
      m.directory "#{plugin_path}/lib/tasks"
      m.directory "#{plugin_path}/assets/images"
      m.directory "#{plugin_path}/assets/javascripts"
      m.directory "#{plugin_path}/assets/stylesheets"
      m.directory "#{plugin_path}/lang"
      
      m.template 'README',    "#{plugin_path}/README"
      m.template 'init.rb',   "#{plugin_path}/init.rb"
      m.template 'en.yml',    "#{plugin_path}/lang/en.yml"
    end
  end
end
