class RedminePluginGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("../templates", __FILE__)

  attr_reader :plugin_path, :plugin_name, :plugin_pretty_name

  def initialize(*args)
    super
    @plugin_name = file_name.underscore
    @plugin_pretty_name = plugin_name.titleize
    @plugin_path = File.join(Redmine::Plugin.directory, plugin_name)
  end

  def copy_templates
    empty_directory "#{plugin_path}/app"
    empty_directory "#{plugin_path}/app/controllers"
    empty_directory "#{plugin_path}/app/helpers"
    empty_directory "#{plugin_path}/app/models"
    empty_directory "#{plugin_path}/app/views"
    empty_directory "#{plugin_path}/db/migrate"
    empty_directory "#{plugin_path}/lib/tasks"
    empty_directory "#{plugin_path}/assets/images"
    empty_directory "#{plugin_path}/assets/javascripts"
    empty_directory "#{plugin_path}/assets/stylesheets"
    empty_directory "#{plugin_path}/config/locales"
    empty_directory "#{plugin_path}/test"
    empty_directory "#{plugin_path}/test/fixtures"
    empty_directory "#{plugin_path}/test/unit"
    empty_directory "#{plugin_path}/test/functional"
    empty_directory "#{plugin_path}/test/integration"

    template 'README.rdoc',    "#{plugin_path}/README.rdoc"
    template 'init.rb.erb',   "#{plugin_path}/init.rb"
    template 'routes.rb',    "#{plugin_path}/config/routes.rb"
    template 'en_rails_i18n.yml',    "#{plugin_path}/config/locales/en.yml"
    template 'test_helper.rb.erb',    "#{plugin_path}/test/test_helper.rb"
  end
end
