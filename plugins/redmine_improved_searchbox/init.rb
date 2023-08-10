# require_dependency 'lib/redmine_improved_searchbox_hook_listener'
require File.dirname(__FILE__) + '/lib/redmine_improved_searchbox_hook_listener'

Redmine::Plugin.register :redmine_improved_searchbox do
  name 'Project Search Box Plugin'
  author 'Ries Technologies'
  description 'This plugin provides enhancement for project search box'
  version '0.0.3'
  url 'https://github.com/ries-tech/redmine_improved_searchbox'
  author_url 'https://github.com/ries-tech/redmine_improved_searchbox'
end
