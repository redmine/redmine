source :rubygems

gem "rails", "2.3.14"
gem "i18n", "~> 0.4.2"
gem "coderay", "~> 1.0.0"
gem "fastercsv", "~> 1.5.0", :platforms => [:mri_18, :mingw_18, :jruby]

# Optional gem for LDAP authentication
group :ldap do
  gem "net-ldap", "~> 0.3.1"
end

# Optional gem for OpenID authentication
group :openid do
  gem "ruby-openid", "~> 2.1.4", :require => "openid"
end

# Optional gem for exporting the gantt to a PNG file
group :rmagick do
  # RMagick 2 supports ruby 1.9
  # RMagick 1 would be fine for ruby 1.8 but Bundler does not support
  # different requirements for the same gem on different platforms
  gem "rmagick", ">= 2.0.0"
end

# Database gems
platforms :mri, :mingw do
  group :postgresql do
    gem "pg", "~> 0.9.0"
  end

  group :sqlite do
    gem "sqlite3"
  end
end

platforms :mri_18, :mingw_18 do
  group :mysql do
    gem "mysql"
  end
end

platforms :mri_19, :mingw_19 do
  group :mysql do
    gem "mysql2", "~> 0.2.7"
  end
end

platforms :jruby do
  gem "jruby-openssl"

  group :mysql do
    gem "activerecord-jdbcmysql-adapter"
  end

  group :postgresql do
    gem "activerecord-jdbcpostgresql-adapter"
  end

  group :sqlite do
    gem "activerecord-jdbcsqlite3-adapter"
  end
end

group :development do
  gem "rdoc", ">= 2.4.2"
end

group :test do
  gem "shoulda", "~> 2.10.3"
  gem "edavis10-object_daddy", :require => "object_daddy"
  gem "mocha"
end

# Load plugins' Gemfiles
Dir.glob File.expand_path("../vendor/plugins/*/Gemfile", __FILE__) do |file|
  puts "Loading #{file} ..." if $DEBUG # `ruby -d` or `bundle -v`
  instance_eval File.read(file)
end
