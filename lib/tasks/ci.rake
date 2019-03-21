desc "Run the Continuous Integration tests for Redmine"
task :ci do
  # RAILS_ENV and ENV[] can diverge so force them both to test
  ENV['RAILS_ENV'] = 'test'
  RAILS_ENV = 'test'
  Rake::Task["ci:setup"].invoke
  Rake::Task["ci:build"].invoke
  Rake::Task["ci:teardown"].invoke
end

namespace :ci do
  desc "Display info about the build environment"
  task :about do
    puts "Ruby version: #{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]"
  end

  desc "Setup Redmine for a new build"
  task :setup do
    Rake::Task["tmp:clear"].invoke
    Rake::Task["log:clear"].invoke
    Rake::Task["db:create:all"].invoke
    Rake::Task["db:migrate"].invoke
    Rake::Task["db:schema:dump"].invoke
    if scms = ENV['SCMS']
      scms.split(',').each do |scm|
        Rake::Task["test:scm:setup:#{scm}"].invoke
      end
    else
      Rake::Task["test:scm:setup:all"].invoke
    end
    Rake::Task["test:scm:update"].invoke
  end

  desc "Build Redmine"
  task :build do
    if test_suite = ENV['TEST_SUITE']
      Rake::Task["test:#{test_suite}"].invoke
    else
      Rake::Task["test"].invoke
    end
    # Rake::Task["test:ui"].invoke
  end

  desc "Finish the build"
  task :teardown do
  end
end

desc "Creates database.yml for the CI server"
file 'config/database.yml' do
  require 'yaml'
  database = ENV['DATABASE_ADAPTER']
  ruby = ENV['RUBY_VER'].gsub('.', '').gsub('-', '')
  branch = ENV['BRANCH'].gsub('.', '').gsub('-', '')
  dev_db_name = "ci_#{branch}_#{ruby}_dev"
  test_db_name = "ci_#{branch}_#{ruby}_test"

  case database
  when /(mysql|mariadb)/
    dev_conf =  {'adapter' => 'mysql2',
                 'database' => dev_db_name, 'host' => 'localhost',
                 'encoding' => 'utf8'}
    if ENV['RUN_ON_NOT_OFFICIAL']
      dev_conf['username'] = 'root'
    else
      dev_conf['username'] = 'jenkins'
      dev_conf['password'] = 'jenkins'
    end
    test_conf = dev_conf.merge('database' => test_db_name)
  when /postgresql/
    dev_conf =  {'adapter' => 'postgresql', 'database' => dev_db_name,
                 'host' => 'localhost'}
    if ENV['RUN_ON_NOT_OFFICIAL']
      dev_conf['username'] = 'postgres'
    else
      dev_conf['username'] = 'jenkins'
      dev_conf['password'] = 'jenkins'
    end
    test_conf = dev_conf.merge('database' => test_db_name)
  when /sqlite3/
    dev_conf =  {'adapter' => (Object.const_defined?(:JRUBY_VERSION) ?
                                 'jdbcsqlite3' : 'sqlite3'),
                 'database' => "db/#{dev_db_name}.sqlite3"}
    test_conf = dev_conf.merge('database' => "db/#{test_db_name}.sqlite3")
  when 'sqlserver'
    dev_conf =  {'adapter' => 'sqlserver', 'database' => dev_db_name,
                 'host' => 'mssqlserver', 'port' => 1433,
                 'username' => 'jenkins', 'password' => 'jenkins'}
    test_conf = dev_conf.merge('database' => test_db_name)
  else
    abort "Unknown database"
  end

  File.open('config/database.yml', 'w') do |f|
    f.write YAML.dump({'development' => dev_conf, 'test' => test_conf})
  end
end
