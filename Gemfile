source 'https://rubygems.org'

gem "bundler", ">= 1.5.0"

gem "rails", "5.2.2"
gem "rouge", "~> 3.3.0"
gem "request_store", "1.0.5"
gem "mini_mime", "~> 1.0.1"
gem "actionpack-xml_parser"
gem "roadie-rails", "~> 1.3.0"
gem "mimemagic"
gem "mail", "~> 2.7.1"
gem "csv", "~> 3.0.1" if RUBY_VERSION >= "2.3" && RUBY_VERSION < "2.6"

gem "nokogiri", (RUBY_VERSION >= "2.3" ? "~> 1.10.0" : "~> 1.9.1")
gem "i18n", "~> 0.7.0"
gem "xpath", "< 3.2.0" if RUBY_VERSION < "2.3"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :x64_mingw, :mswin]
gem "rbpdf", "~> 1.19.6"

# Optional gem for LDAP authentication
group :ldap do
  gem "net-ldap", "~> 0.16.0"
end

# Optional gem for OpenID authentication
group :openid do
  gem "ruby-openid", "~> 2.3.0", :require => "openid"
  gem "rack-openid"
end

platforms :mri, :mingw, :x64_mingw do
  # Optional gem for exporting the gantt to a PNG file, not supported with jruby
  group :rmagick do
    gem "rmagick", "~> 2.16.0"
  end

  # Optional Markdown support, not for JRuby
  group :markdown do
    gem "redcarpet", "~> 3.4.0"
  end
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
        gem "sqlite3", "~>1.3.12", :platforms => [:mri, :mingw, :x64_mingw]
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
  gem "mocha"
  gem "simplecov", "~> 0.14.1", :require => false
  # For running system tests
  gem 'puma', '~> 3.7'
  gem "capybara", '~> 2.13'
  gem "selenium-webdriver"
end

local_gemfile = File.join(File.dirname(__FILE__), "Gemfile.local")
if File.exists?(local_gemfile)
  eval_gemfile local_gemfile
end

# Load plugins' Gemfiles
Dir.glob File.expand_path("../plugins/*/{Gemfile,PluginGemfile}", __FILE__) do |file|
  eval_gemfile file
end
