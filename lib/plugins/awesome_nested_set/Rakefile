# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require 'rubygems'
require 'bundler/setup'
require 'awesome_nested_set/version'

task :default => :spec

task :spec do
  %w(3.0 3.1 3.2).each do |rails_version|
    puts "\n" + (cmd = "BUNDLE_GEMFILE='gemfiles/Gemfile.rails-#{rails_version}.rb' bundle exec rspec spec")
    system cmd
  end
end

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
