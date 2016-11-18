class RedminePluginModelGenerator < Rails::Generators::NamedBase
  
  source_root File.expand_path("../templates", __FILE__)
  argument :model, :type => :string
  argument :attributes, :type => :array, :default => [], :banner => "field[:type][:index] field[:type][:index]"
  class_option :migration,  :type => :boolean
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
    
    migration_filename = "%03i_#{@migration_filename}.rb" % (migration_number + 1)
    template "migration.rb", "#{plugin_path}/db/migrate/#{migration_filename}"
  end

  def attributes_with_index
    attributes.select { |a| a.has_index? || (a.reference? && options[:indexes]) }
  end

  def migration_number
    current = Dir.glob("#{plugin_path}/db/migrate/*.rb").map do |file|
      File.basename(file).split("_").first.to_i
    end.max.to_i
  end
end
