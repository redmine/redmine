require 'redmine'

Redmine::Plugin.register :redmine_bitbucket_hook do
  name 'Redmine Bitbucket Hook plugin'
  author 'Alessio Caiazza, Peter Sanchez'
  description 'This plugin allows your Redmine installation to receive Bitbucket post-receive notifications. Based on github work by Jakob Skjerning.'
  version '0.1.3'
end
