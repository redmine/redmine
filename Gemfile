source 'https://rubygems.org'

ruby '>= 2.5.0', '< 3.2.0'
gem 'bundler', '>= 1.12.0'

gem 'rails', '6.1.4.4'
gem 'globalid', '~> 0.4.2' if Gem.ruby_version < Gem::Version.new('2.6.0')
gem 'rouge', '~> 3.28.0'
gem 'request_store', '~> 1.5.0'
gem 'mini_mime', '~> 1.1.0'
gem "actionpack-xml_parser"
gem 'roadie-rails', (Gem.ruby_version < Gem::Version.new('2.6.0') ? '~> 2.2.0' : '~> 2.3.0')
gem 'marcel'
gem "mail", "~> 2.7.1"
gem 'csv', '~> 3.2.0'
gem 'nokogiri', (Gem.ruby_version < Gem::Version.new('2.6.0') ? '~> 1.12.2' : '~> 1.13.0')
gem 'i18n', '~> 1.9.1'
gem "rbpdf", "~> 1.20.0"
gem 'addressable'
gem 'rubyzip', '~> 2.3.0'
gem 'net-smtp', '~> 0.3.0'
gem 'net-imap', '~> 0.2.2'
gem 'net-pop', '~> 0.1.1'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :x64_mingw, :mswin]

# TOTP-based 2-factor authentication
gem 'rotp'
gem 'rqrcode'

# Optional gem for LDAP authentication
group :ldap do
  gem 'net-ldap', '~> 0.17.0'
end

# Optional gem for exporting the gantt to a PNG file
group :minimagick do
  gem 'mini_magick', '~> 4.11.0'
end

# Optional Markdown support, not for JRuby
group :markdown do
  gem 'redcarpet', '~> 3.5.1'
end

# Optional CommonMark support, not for JRuby
group :common_mark do
  gem "html-pipeline", "~> 2.13.2"
  gem "commonmarker", (Gem.ruby_version < Gem::Version.new('2.6.0') ? '0.21.0' : '0.23.1')
  gem "sanitize", "~> 6.0"
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
  adapters = database_config.values.map {|c| c['adapter']}.compact.uniq
  if adapters.any?
    adapters.each do |adapter|
      case adapter
      when 'mysql2'
        gem "mysql2", "~> 0.5.0", :platforms => [:mri, :mingw, :x64_mingw]
      when /postgresql/
        gem "pg", "~> 1.2.2", :platforms => [:mri, :mingw, :x64_mingw]
      when /sqlite3/
        gem "sqlite3", "~> 1.4.0", :platforms => [:mri, :mingw, :x64_mingw]
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
  gem 'mocha', '>= 1.4.0'
  gem 'simplecov', '~> 0.21.2', :require => false
  gem "ffi", platforms: [:mingw, :x64_mingw, :mswin]
  # For running system tests
  gem 'puma'
  gem 'capybara', (Gem.ruby_version < Gem::Version.new('2.6.0') ? '~> 3.35.3' : '~> 3.36.0')
  gem "selenium-webdriver", "~> 3.142.7"
  gem 'webdrivers', '4.6.1', require: false
  # RuboCop
  gem 'rubocop', '~> 1.25.0'
  gem 'rubocop-performance', '~> 1.13.0'
  gem 'rubocop-rails', '~> 2.13.0'
end

local_gemfile = File.join(File.dirname(__FILE__), "Gemfile.local")
if File.exist?(local_gemfile)
  eval_gemfile local_gemfile
end

# Load plugins' Gemfiles
Dir.glob File.expand_path("../plugins/*/{Gemfile,PluginGemfile}", __FILE__) do |file|
  eval_gemfile file
end
