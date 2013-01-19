desc "Run the Continous Integration tests for Redmine"
task :ci do
  # RAILS_ENV and ENV[] can diverge so force them both to test
  ENV['RAILS_ENV'] = 'test'
  RAILS_ENV = 'test'
  Rake::Task["ci:setup"].invoke
  Rake::Task["ci:build"].invoke
  Rake::Task["ci:teardown"].invoke
end

# Tasks can be hooked into by redefining them in a plugin
namespace :ci do
  desc "Setup Redmine for a new build."
  task :setup do
    Rake::Task["ci:dump_environment"].invoke
    Rake::Task["db:create"].invoke
    Rake::Task["db:migrate"].invoke
    Rake::Task["db:schema:dump"].invoke
    Rake::Task["test:scm:update"].invoke
  end

  desc "Build Redmine"
  task :build do
    Rake::Task["test"].invoke
  end

  # Use this to cleanup after building or run post-build analysis.
  desc "Finish the build"
  task :teardown do
  end

  desc "Creates and configures the databases for the CI server"
  task :database do
    path = 'config/database.yml'
    unless File.exists?(path)
      database = ENV['DATABASE_ADAPTER']
      ruby = ENV['RUBY_VER'].gsub('.', '').gsub('-', '')
      branch = ENV['BRANCH'].gsub('.', '').gsub('-', '')
      dev_db_name = "ci_#{branch}_#{ruby}_dev"
      test_db_name = "ci_#{branch}_#{ruby}_test"

      case database
      when 'mysql'
        raise "Error creating databases" unless
          system(%|mysql -u jenkins --password=jenkins -e 'create database #{dev_db_name} character set utf8;'|) &&
          system(%|mysql -u jenkins --password=jenkins -e 'create database #{test_db_name} character set utf8;'|)
        dev_conf =  { 'adapter' => (RUBY_VERSION >= '1.9' ? 'mysql2' : 'mysql'), 'database' => dev_db_name, 'host' => 'localhost', 'username' => 'jenkins', 'password' => 'jenkins', 'encoding' => 'utf8' }
        test_conf = { 'adapter' => (RUBY_VERSION >= '1.9' ? 'mysql2' : 'mysql'), 'database' => test_db_name, 'host' => 'localhost', 'username' => 'jenkins', 'password' => 'jenkins', 'encoding' => 'utf8' }
      when 'postgresql'
        raise "Error creating databases" unless
          system(%|psql -U jenkins -d postgres -c "create database #{dev_db_name} owner jenkins encoding 'UTF8';"|) &&
          system(%|psql -U jenkins -d postgres -c "create database #{test_db_name} owner jenkins encoding 'UTF8';"|)
        dev_conf =  { 'adapter' => 'postgresql', 'database' => dev_db_name, 'host' => 'localhost', 'username' => 'jenkins', 'password' => 'jenkins' }
        test_conf = { 'adapter' => 'postgresql', 'database' => test_db_name, 'host' => 'localhost', 'username' => 'jenkins', 'password' => 'jenkins' }
      when 'sqlite3'
        dev_conf =  { 'adapter' => 'sqlite3', 'database' => "db/#{dev_db_name}.sqlite3" }
        test_conf = { 'adapter' => 'sqlite3', 'database' => "db/#{test_db_name}.sqlite3" }
      when 'sqlserver'
        dev_conf =  { 'adapter' => 'sqlserver', 'database' => dev_db_name, 'host' => 'mssqlserver', 'port' => 1433, 'username' => 'jenkins', 'password' => 'jenkins' }
        test_conf = { 'adapter' => 'sqlserver', 'database' => test_db_name, 'host' => 'mssqlserver', 'port' => 1433, 'username' => 'jenkins', 'password' => 'jenkins' }
      else
        raise "Unknown database"
      end

      File.open(path, 'w') do |f|
        f.write YAML.dump({'development' => dev_conf, 'test' => test_conf})
      end
    end
  end

  desc "Dump the environment information to a BUILD_ENVIRONMENT ENV variable for debugging"
  task :dump_environment do

    ENV['BUILD_ENVIRONMENT'] = ['ruby -v', 'gem -v', 'gem list'].collect do |command|
      result = `#{command}`
      "$ #{command}\n#{result}"
    end.join("\n")

  end
end

