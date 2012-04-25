# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require 'rubygems'
require 'bundler/setup'
require 'awesome_nested_set/version'

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

task :default => :spec

task :build do
  system "gem build awesome_nested_set.gemspec"
end

task :release => :build do
  system "gem push awesome_nested_set-#{ActsAsGeocodable::VERSION}.gem"
end

require 'rdoc/task'
desc 'Generate documentation for the awesome_nested_set plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'AwesomeNestedSet'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
