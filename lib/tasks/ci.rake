desc "Run the Continous Integration tests for Redmine"
task :ci do
  # RAILS_ENV and ENV[] can diverge so force them both to test
  ENV['RAILS_ENV'] = 'test'
  RAILS_ENV = 'test'
  Rake::Task["ci:setup"].invoke
  Rake::Task["ci:build"].invoke
  Rake::Task["ci:teardown"].invoke
end

namespace :ci do
  desc "Setup Redmine for a new build"
  task :setup do
    Rake::Task["tmp:clear"].invoke
    Rake::Task["log:clear"].invoke
    Rake::Task["db:create:all"].invoke
    Rake::Task["db:migrate"].invoke
    Rake::Task["db:schema:dump"].invoke
    Rake::Task["test:scm:setup:all"].invoke
    Rake::Task["test:scm:update"].invoke
  end

  desc "Build Redmine"
  task :build do
    Rake::Task["test"].invoke
    # Rake::Task["test:ui"].invoke if RUBY_VERSION >= '1.9.3'
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
  when 'mysql'
    dev_conf =  {'adapter' => (RUBY_VERSION >= '1.9' ? 'mysql2' : 'mysql'), 'database' => dev_db_name, 'host' => 'localhost', 'username' => 'jenkins', 'password' => 'jenkins', 'encoding' => 'utf8'}
    test_conf = dev_conf.merge('database' => test_db_name)
  when 'postgresql'
    dev_conf =  {'adapter' => 'postgresql', 'database' => dev_db_name, 'host' => 'localhost', 'username' => 'jenkins', 'password' => 'jenkins'}
    test_conf = dev_conf.merge('database' => test_db_name)
  when 'sqlite3'
    dev_conf =  {'adapter' => 'sqlite3', 'database' => "db/#{dev_db_name}.sqlite3"}
    test_conf = dev_conf.merge('database' => "db/#{test_db_name}.sqlite3")
  when 'sqlserver'
    dev_conf =  {'adapter' => 'sqlserver', 'database' => dev_db_name, 'host' => 'mssqlserver', 'port' => 1433, 'username' => 'jenkins', 'password' => 'jenkins'}
    test_conf = dev_conf.merge('database' => test_db_name)
  else
    abort "Unknown database"
  end

  File.open('config/database.yml', 'w') do |f|
    f.write YAML.dump({'development' => dev_conf, 'test' => test_conf})
  end
end
