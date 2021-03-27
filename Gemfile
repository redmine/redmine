source 'https://rubygems.org'

ruby '>= 2.4.0', '< 2.8.0'
gem 'bundler', '>= 1.12.0'

gem 'rails', '5.2.5'
gem 'sprockets', '~> 3.7.2' if RUBY_VERSION < '2.5'
gem 'rouge', '~> 3.26.0'
gem 'request_store', '~> 1.5.0'
gem "mini_mime", "~> 1.0.1"
gem "actionpack-xml_parser"
gem 'roadie-rails', (RUBY_VERSION < '2.5' ? '~> 1.3.0' : '~> 2.2.0')
gem 'marcel'
gem "mail", "~> 2.7.1"
gem 'csv', (RUBY_VERSION < '2.5' ? ['>= 3.1.1', '<= 3.1.5'] : '~> 3.1.1')
gem 'nokogiri', (RUBY_VERSION < '2.5' ? '~> 1.10.0' : '~> 1.11.1')
gem 'i18n', '~> 1.8.2'
gem "rbpdf", "~> 1.20.0"
gem 'addressable'
gem 'rubyzip', '~> 2.3.0'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :x64_mingw, :mswin]

# TOTP-based 2-factor authentication
gem 'rotp'
gem 'rqrcode'

# Optional gem for LDAP authentication
group :ldap do
  gem 'net-ldap', '~> 0.17.0'
end

# Optional gem for OpenID authentication
group :openid do
  gem "ruby-openid", "~> 2.9.2", :require => "openid"
  gem "rack-openid"
end

# Optional gem for exporting the gantt to a PNG file
group :minimagick do
  gem 'mini_magick', '~> 4.11.0'
end

# Optional Markdown support, not for JRuby
group :markdown do
  gem 'redcarpet', '~> 3.5.1'
end

# Include database gems for the adapters found in the database
# configuration file
require 'erb'
require 'yaml'
database_file = File.join(File.dirname(__FILE__), "config/database.yml")
if File.exist?(database_file)
  database_config = YAML::load(ERB.new(IO.read(database_file)).result)
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
        gem "activerecord-sqlserver-adapter", "~> 5.2.1", :platforms => [:mri, :mingw, :x64_mingw]
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
  gem "yard"
end

group :test do
  gem "rails-dom-testing"
  gem 'mocha', '>= 1.4.0'
  gem 'simplecov', '~> 0.18.5', :require => false
  gem "ffi", platforms: [:mingw, :x64_mingw, :mswin]
  # For running system tests
  gem 'puma'
  gem 'capybara', '~> 3.31.0'
  gem "selenium-webdriver"
  gem 'webdrivers', '~> 4.4', require: false
  # RuboCop
  gem 'rubocop', '~> 1.12.0'
  gem 'rubocop-performance', '~> 1.10.1'
  gem 'rubocop-rails', '~> 2.9.0'
end

local_gemfile = File.join(File.dirname(__FILE__), "Gemfile.local")
if File.exists?(local_gemfile)
  eval_gemfile local_gemfile
end

# Load plugins' Gemfiles
Dir.glob File.expand_path("../plugins/*/{Gemfile,PluginGemfile}", __FILE__) do |file|
  eval_gemfile file
end
