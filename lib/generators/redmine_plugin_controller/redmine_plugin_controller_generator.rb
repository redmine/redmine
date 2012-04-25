class RedminePluginControllerGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("../templates", __FILE__)
  argument :controller, :type => :string
  argument :actions, :type => :array, :default => [], :banner => "ACTION ACTION ..."

  attr_reader :plugin_path, :plugin_name, :plugin_pretty_name

  def initialize(*args)
    super
    @plugin_name = file_name.underscore
    @plugin_pretty_name = plugin_name.titleize
    @plugin_path = "plugins/#{plugin_name}"
    @controller_class = controller.camelize
  end

  def copy_templates
    template 'controller.rb.erb', "#{plugin_path}/app/controllers/#{controller}_controller.rb"
    template 'helper.rb.erb', "#{plugin_path}/app/helpers/#{controller}_helper.rb"
    template 'functional_test.rb.erb', "#{plugin_path}/test/functional/#{controller}_controller_test.rb"
    # View template for each action.
    actions.each do |action|
      path = "#{plugin_path}/app/views/#{controller}/#{action}.html.erb"
      @action_name = action
      template 'view.html.erb', path
    end
  end
end
