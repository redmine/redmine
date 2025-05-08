Redmine::Plugin.register :redmine_test_plugin_foo do
  name 'Test plugin redmine_test_plugin_foo'
  author 'Author name'
  description 'This is a plugin for Redmine test'
  version '0.0.1'
end

Redmine::Acts::Attachable::ObjectTypeConstraint.register_object_type('plugin_articles')

Pathname(__dir__).glob("app/**/*.rb").sort.each do |path|
  require path
end
