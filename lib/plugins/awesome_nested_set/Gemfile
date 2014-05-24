gem 'combustion', :github => 'pat/combustion', :branch => 'master'

source 'https://rubygems.org'

gemspec :path => File.expand_path('../', __FILE__)

platforms :jruby do
  gem 'activerecord-jdbcsqlite3-adapter'
  gem 'activerecord-jdbcmysql-adapter'
  gem 'jdbc-mysql'
  gem 'activerecord-jdbcpostgresql-adapter'
  gem 'jruby-openssl'
end

platforms :ruby do
  gem 'sqlite3'
  gem 'mysql2', (MYSQL2_VERSION if defined? MYSQL2_VERSION)
  gem 'pg'
end

RAILS_VERSION = nil unless defined? RAILS_VERSION
gem 'railties', RAILS_VERSION
gem 'activerecord', RAILS_VERSION
gem 'actionpack', RAILS_VERSION

# Add Oracle Adapters
# gem 'ruby-oci8'
# gem 'activerecord-oracle_enhanced-adapter'

# Debuggers
gem 'pry'
gem 'pry-nav'
