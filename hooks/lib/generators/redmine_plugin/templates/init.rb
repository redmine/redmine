require 'redmine'

Redmine::Plugin.register :<%= plugin_name %> do
  name 'Example plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
end
