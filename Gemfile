source 'https://rubygems.org'

ruby '>= 2.7.0', '< 3.3.0'

gem 'rails', '6.1.7.7'
gem 'rouge', '~> 4.2.0'
gem 'request_store', '~> 1.5.0'
gem 'mini_mime', '~> 1.1.0'
gem "actionpack-xml_parser"
gem 'roadie-rails', '~> 3.1.0'
gem 'marcel'
gem 'mail', '~> 2.8.1'
gem 'nokogiri', '~> 1.15.2'
gem 'i18n', '~> 1.14.1'
gem 'rbpdf', '~> 1.21.3'
gem 'addressable'
gem 'rubyzip', '~> 2.3.0'

#  Ruby Standard Gems
gem 'csv', '~> 3.2.6'
gem 'net-imap', '~> 0.3.4'
gem 'net-pop', '~> 0.1.2'
gem 'net-smtp', '~> 0.3.3'
gem 'rexml', require: false if Gem.ruby_version >= Gem::Version.new('3.0')

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :x64_mingw, :mswin]

# TOTP-based 2-factor authentication
gem 'rotp', '>= 5.0.0'
gem 'rqrcode'

# HTML pipeline and sanitization
gem "html-pipeline", "~> 2.13.2"
gem "sanitize", "~> 6.0"

# Optional gem for LDAP authentication
group :ldap do
  gem 'net-ldap', '~> 0.17.0'
end

# Optional gem for exporting the gantt to a PNG file
group :minimagick do
  gem 'mini_magick', '~> 4.12.0'
end

# Optional Markdown support
group :markdown do
  gem 'redcarpet', '~> 3.6.0'
end

# Optional CommonMark support, not for JRuby
group :common_mark do
  gem "commonmarker", '~> 0.23.8'
  gem 'deckar01-task_list', '2.3.2'
end

# Include database gems for the adapters found in the database
# configuration file
require 'erb'
require 'yaml'
database_file = File.join(File.dirname(__FILE__), "config/database.yml")
if File.exist?(database_file)
  yaml_config = ERB.new(IO.read(database_file)).result
  database_config = YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(yaml_config) : YAML.load(yaml_config)
  adapters = database_config.values.filter_map {|c| c['adapter']}.uniq
  if adapters.any?
    adapters.each do |adapter|
      case adapter
      when 'mysql2'
        gem "mysql2", "~> 0.5.0", :platforms => [:mri, :mingw, :x64_mingw]
        gem "with_advisory_lock"
      when /postgresql/
        gem 'pg', '~> 1.5.3', :platforms => [:mri, :mingw, :x64_mingw]
      when /sqlite3/
        gem 'sqlite3', '~> 1.6.0', :platforms => [:mri, :mingw, :x64_mingw]
      when /sqlserver/
        gem "tiny_tds", "~> 2.1.2", :platforms => [:mri, :mingw, :x64_mingw]
        gem "activerecord-sqlserver-adapter", "~> 6.1.0", :platforms => [:mri, :mingw, :x64_mingw]
      else
        warn("Unknown database adapter `#{adapter}` found in config/database.yml, use Gemfile.local to load your own database gems")
      end
    end
  else
    warn("No adapter found in config/database.yml, please configure it first")
  end
else
  warn("Please configure your config/database.yml first")
end

group :development do
  gem 'listen', '~> 3.3'
  gem "yard"
end

group :test do
  gem "rails-dom-testing"
  gem 'mocha', '>= 2.0.1'
  gem 'simplecov', '~> 0.22.0', :require => false
  gem "ffi", platforms: [:mingw, :x64_mingw, :mswin]
  # For running system tests
  gem 'puma'
  gem "capybara", ">= 3.39"
  if Gem.ruby_version < Gem::Version.new('3.0')
    gem "selenium-webdriver", "<= 4.9.0"
    gem "webdrivers", require: false
  else
    gem "selenium-webdriver", ">= 4.11.0"
  end
  # RuboCop
  gem 'rubocop', '~> 1.57.0', require: false
  gem 'rubocop-performance', '~> 1.19.0', require: false
  gem 'rubocop-rails', '~> 2.22.1', require: false
end

local_gemfile = File.join(File.dirname(__FILE__), "Gemfile.local")
if File.exist?(local_gemfile)
  eval_gemfile local_gemfile
end

# Load plugins' Gemfiles
Dir.glob File.expand_path("../plugins/*/{Gemfile,PluginGemfile}", __FILE__) do |file|
  eval_gemfile file
end
