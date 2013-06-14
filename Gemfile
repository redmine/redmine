source 'https://rubygems.org'

gem "rails", "3.2.13"
gem "jquery-rails", "~> 2.0.2"
gem "i18n", "~> 0.6.0"
gem "coderay", "~> 1.0.9"
gem "fastercsv", "~> 1.5.0", :platforms => [:mri_18, :mingw_18, :jruby]
gem "builder", "3.0.0"

# Optional gem for LDAP authentication
group :ldap do
  gem "net-ldap", "~> 0.3.1"
end

# Optional gem for OpenID authentication
group :openid do
  gem "ruby-openid", "~> 2.1.4", :require => "openid"
  gem "rack-openid"
end

# Optional gem for exporting the gantt to a PNG file, not supported with jruby
platforms :mri, :mingw do
  group :rmagick do
    # RMagick 2 supports ruby 1.9
    # RMagick 1 would be fine for ruby 1.8 but Bundler does not support
    # different requirements for the same gem on different platforms
    gem "rmagick", ">= 2.0.0"
  end
end

platforms :jruby do
  # jruby-openssl is bundled with JRuby 1.7.0
  gem "jruby-openssl" if Object.const_defined?(:JRUBY_VERSION) && JRUBY_VERSION < '1.7.0'
  gem "activerecord-jdbc-adapter", "1.2.5"
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
        gem "mysql2", "~> 0.3.11", :platforms => [:mri, :mingw]
        gem "activerecord-jdbcmysql-adapter", :platforms => :jruby
      when 'mysql'
        gem "mysql", "~> 2.8.1", :platforms => [:mri, :mingw]
        gem "activerecord-jdbcmysql-adapter", :platforms => :jruby
      when /postgresql/
        gem "pg", ">= 0.11.0", :platforms => [:mri, :mingw]
        gem "activerecord-jdbcpostgresql-adapter", :platforms => :jruby
      when /sqlite3/
        gem "sqlite3", :platforms => [:mri, :mingw]
        gem "activerecord-jdbcsqlite3-adapter", :platforms => :jruby
      when /sqlserver/
        gem "tiny_tds", "~> 0.5.1", :platforms => [:mri, :mingw]
        gem "activerecord-sqlserver-adapter", :platforms => [:mri, :mingw]
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
  gem "rdoc", ">= 2.4.2"
  gem "yard"
end

group :test do
  gem "shoulda", "~> 3.3.2"
  gem "mocha", ">= 0.14", :require => 'mocha/api'
  if RUBY_VERSION >= '1.9.3'
    gem "capybara", "~> 2.1.0"
    gem "selenium-webdriver"
    gem "database_cleaner"
  end
end

local_gemfile = File.join(File.dirname(__FILE__), "Gemfile.local")
if File.exists?(local_gemfile)
  puts "Loading Gemfile.local ..." if $DEBUG # `ruby -d` or `bundle -v`
  instance_eval File.read(local_gemfile)
end

# Load plugins' Gemfiles
Dir.glob File.expand_path("../plugins/*/Gemfile", __FILE__) do |file|
  puts "Loading #{file} ..." if $DEBUG # `ruby -d` or `bundle -v`
  #TODO: switch to "eval_gemfile file" when bundler >= 1.2.0 will be required (rails 4)
  instance_eval File.read(file), file
end
