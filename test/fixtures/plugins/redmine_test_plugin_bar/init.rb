Redmine::Plugin.register :redmine_test_plugin_bar do
  name 'Test plugin redmine_test_plugin_bar'
  author 'Author name'
  description 'This is a plugin for Redmine test'
  version '0.0.1'
end

Pathname(__dir__).glob("app/**/*.rb").sort.each do |path|
  require path
end
