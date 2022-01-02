# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

class RedminePluginControllerGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("../templates", __FILE__)
  argument :controller, :type => :string
  argument :actions, :type => :array, :default => [], :banner => "ACTION ACTION ..."

  attr_reader :plugin_path, :plugin_name, :plugin_pretty_name

  def initialize(*args)
    super
    @plugin_name = file_name.underscore
    @plugin_pretty_name = plugin_name.titleize
    @plugin_path = File.join(Redmine::Plugin.directory, plugin_name)
    @controller_class = controller.camelize
  end

  def copy_templates
    template 'controller.rb.erb', "#{plugin_path}/app/controllers/#{controller.underscore}_controller.rb"
    template 'helper.rb.erb', "#{plugin_path}/app/helpers/#{controller.underscore}_helper.rb"
    template 'functional_test.rb.erb', "#{plugin_path}/test/functional/#{controller.underscore}_controller_test.rb"
    # View template for each action.
    actions.each do |action|
      path = "#{plugin_path}/app/views/#{controller.underscore}/#{action}.html.erb"
      @action_name = action
      template 'view.html.erb', path
    end
  end
end
