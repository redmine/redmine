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

class RedminePluginModelGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("../templates", __FILE__)
  argument :model, :type => :string
  argument :attributes, :type => :array, :default => [], :banner => "field[:type][:index] field[:type][:index]"
  class_option :migration,  :type => :boolean, :default => true
  class_option :timestamps, :type => :boolean
  class_option :parent,     :type => :string, :desc => "The parent class for the generated model"
  class_option :indexes,    :type => :boolean, :default => true, :desc => "Add indexes for references and belongs_to columns"

  attr_reader :plugin_path, :plugin_name, :plugin_pretty_name

  def initialize(*args)
    super
    @plugin_name = file_name.underscore
    @plugin_pretty_name = plugin_name.titleize
    @plugin_path = File.join(Redmine::Plugin.directory, plugin_name)
    @model_class = model.camelize
    @table_name = @model_class.tableize
    @migration_filename = "create_#{@table_name}"
    @migration_class_name = @migration_filename.camelize
  end

  def copy_templates
    template 'model.rb.erb', "#{plugin_path}/app/models/#{model.underscore}.rb"
    template 'unit_test.rb.erb', "#{plugin_path}/test/unit/#{model.underscore}_test.rb"
    return unless options[:migration]

    migration_filename = "%.14d_#{@migration_filename}.rb" % migration_number
    template "migration.rb", "#{plugin_path}/db/migrate/#{migration_filename}"
  end

  private

  def attributes_with_index
    attributes.select {|a| a.has_index? || (a.reference? && options[:indexes])}
  end

  def migration_number
    current = Dir.glob("#{plugin_path}/db/migrate/*.rb").map do |file|
      File.basename(file).split("_").first.to_i
    end.max.to_i

    [current + 1, Time.now.utc.strftime("%Y%m%d%H%M%S").to_i].max
  end

  def parent_class_name
    options[:parent] || "ActiveRecord::Base"
  end
end
