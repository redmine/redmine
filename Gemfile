source 'https://rubygems.org'

ruby '>= 3.1.0', '< 3.4.0'

gem 'rails', '7.2.2.1'
gem 'rouge', '~> 4.5'
gem 'mini_mime', '~> 1.1.0'
gem "actionpack-xml_parser"
gem 'roadie-rails', '~> 3.2.0'
gem 'marcel'
gem 'mail', '~> 2.8.1'
gem 'nokogiri', '~> 1.18.3'
gem 'i18n', '~> 1.14.1'
gem 'rbpdf', '~> 1.21.3'
gem 'addressable'
gem 'rubyzip', '~> 2.3.0'
gem 'propshaft', '~> 1.1.0'
gem 'rack', '>= 3.1.3'

#  Ruby Standard Gems
gem 'csv', '~> 3.2.8'
gem 'net-imap', '~> 0.4.8'
gem 'net-pop', '~> 0.1.2'
gem 'net-smtp', '~> 0.4.0'

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
  gem 'mini_magick', '~> 5.0.1'
end

# Optional CommonMark support, not for JRuby
group :common_mark do
  gem "commonmarker", '~> 0.23.8'
  gem 'deckar01-task_list', '2.3.2'
end

# Include database gems for the adapters found in the database
# configuration file
database_file = File.join(File.dirname(__FILE__), "config/database.yml")
if File.exist?(database_file)
  database_config = File.read(database_file)

  # Requiring libraries in a Gemfile may cause Bundler warnings or
  # unexpected behavior, especially if multiple gem versions are available.
  # So, process database.yml through ERB only if it contains ERB syntax
  # in the adapter setting. See https://www.redmine.org/issues/41749.
  if database_config.match?(/^ *adapter: *<%=/)
    require 'erb'
    database_config = ERB.new(database_config).result
  end

  adapters = database_config.scan(/^ *adapter: *(.*)/).flatten.uniq
  if adapters.any?
    adapters.each do |adapter|
      case adapter.strip
      when /mysql2/
        gem 'mysql2', '~> 0.5.0'
        gem "with_advisory_lock"
      when /postgresql/
        gem 'pg', '~> 1.5.3'
      when /sqlite3/
        gem 'sqlite3', '~> 1.7.0'
      when /sqlserver/
        gem 'tiny_tds', '~> 2.1.2'
        gem 'activerecord-sqlserver-adapter', '~> 7.2.0'
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

group :development, :test do
  gem 'debug'
end

group :development do
  gem 'listen', '~> 3.3'
  gem 'yard', require: false
  gem 'svg_sprite', require: false
end

group :test do
  gem "rails-dom-testing"
  gem 'mocha', '>= 2.0.1'
  gem 'simplecov', '~> 0.22.0', :require => false
  gem "ffi", platforms: [:mingw, :x64_mingw, :mswin]
  # For running system tests
  gem 'puma'
  gem "capybara", ">= 3.39"
  gem 'selenium-webdriver', '>= 4.11.0'
  # RuboCop
  gem 'rubocop', '~> 1.68.0', require: false
  gem 'rubocop-performance', '~> 1.22.0', require: false
  gem 'rubocop-rails', '~> 2.27.0', require: false
  gem 'bundle-audit', require: false
end

local_gemfile = File.join(File.dirname(__FILE__), "Gemfile.local")
if File.exist?(local_gemfile)
  eval_gemfile local_gemfile
end

# Load plugins' Gemfiles
Dir.glob File.expand_path("../plugins/*/{Gemfile,PluginGemfile}", __FILE__) do |file|
  eval_gemfile file
end
