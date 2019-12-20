source 'https://rubygems.org'

gem "bundler", ">= 1.5.0"

gem "rails", "5.2.4.1"
gem "rouge", "~> 3.12.0"
gem "request_store", "~> 1.4.1"
gem "mini_mime", "~> 1.0.1"
gem "actionpack-xml_parser"
gem "roadie-rails", (RUBY_VERSION < "2.5" ? "~> 1.3.0" : "~> 2.1.0")
gem "mimemagic"
gem "mail", "~> 2.7.1"
gem "csv", "~> 3.1.1"
gem "nokogiri", "~> 1.10.0"
gem "i18n", "~> 1.6.0"
gem "rbpdf", "~> 1.20.0"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :x64_mingw, :mswin]

# Optional gem for LDAP authentication
group :ldap do
  gem "net-ldap", "~> 0.16.0"
end

# Optional gem for OpenID authentication
group :openid do
  gem "ruby-openid", "~> 2.9.2", :require => "openid"
  gem "rack-openid"
end

# Optional gem for exporting the gantt to a PNG file
group :minimagick do
  gem "mini_magick", "~> 4.9.5"
end

# Optional Markdown support, not for JRuby
group :markdown do
  gem "redcarpet", "~> 3.5.0"
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
        gem "pg", "~> 1.1.4", :platforms => [:mri, :mingw, :x64_mingw]
      when /sqlite3/
        gem "sqlite3", "~> 1.4.0", :platforms => [:mri, :mingw, :x64_mingw]
      when /sqlserver/
        gem "tiny_tds", "~> 1.0.5", :platforms => [:mri, :mingw, :x64_mingw]
        gem "activerecord-sqlserver-adapter", :platforms => [:mri, :mingw, :x64_mingw]
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
  gem "simplecov", "~> 0.17.0", :require => false
  gem "ffi", platforms: [:mingw, :x64_mingw, :mswin]
  # For running system tests
  gem 'puma', '~> 3.7'
  gem "capybara", (RUBY_VERSION < "2.4" ? "~> 3.15.1" : "~> 3.25.0")
  gem "selenium-webdriver"
  # RuboCop
  gem 'rubocop', '~> 0.76.0'
  gem 'rubocop-performance', '~> 1.5.0'
  gem 'rubocop-rails', '~> 2.3.0'
end

local_gemfile = File.join(File.dirname(__FILE__), "Gemfile.local")
if File.exists?(local_gemfile)
  eval_gemfile local_gemfile
end

# Load plugins' Gemfiles
Dir.glob File.expand_path("../plugins/*/{Gemfile,PluginGemfile}", __FILE__) do |file|
  eval_gemfile file
end
