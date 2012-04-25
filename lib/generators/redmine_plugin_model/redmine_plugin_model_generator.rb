class RedminePluginModelGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("../templates", __FILE__)
  argument :model, :type => :string

  attr_reader :plugin_path, :plugin_name, :plugin_pretty_name

  def initialize(*args)
    super
    @plugin_name = file_name.underscore
    @plugin_pretty_name = plugin_name.titleize
    @plugin_path = "plugins/#{plugin_name}"
    @model_class = model.camelize
  end

  def copy_templates
    template 'model.rb.erb', "#{plugin_path}/app/models/#{model}.rb"
    template 'unit_test.rb.erb', "#{plugin_path}/test/unit/#{model}_test.rb"
  end
end
