# config valid only for current version of Capistrano
# lock "3.7.2"

set :application, "softra-redmine"
set :repo_url, "git@github.com:wisemonks/softra-redmine.git"
set :branch, "master"

set :deploy_to, '/home/op'
set :rails_env, "production"

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
# set :deploy_to, "/var/www/my_app_name"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true
require 'capistrano-db-tasks'

# if you want to remove the local dump file after loading
set :db_local_clean, true

# if you want to remove the dump file from the server after downloading
set :db_remote_clean, true

# if you want to exclude table from dump
set :db_ignore_tables, []

# if you want to exclude table data (but not table schema) from dump
set :db_ignore_data_tables, []

# configure location where the dump file should be created
set :db_dump_dir, "./db"


set :rbenv_map_bins, %w(rake gem bundle ruby rails pumactl puma)


set :rbenv_custom_path, '/home/op/.rbenv'
set :rbenv_type, :system
set :rbenv_ruby, '3.1.2'
rbenv_prefix = [
  "RBENV_ROOT=#{fetch(:rbenv_path)}",
  "RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
]
set :rbenv_prefix, rbenv_prefix.join(' ')

# Configure 'whenever'
# Whenever config
set :whenever_environment, fetch(:stage)
set :whenever_identifier, "#{fetch(:application)}_#{fetch(:stage)}"
set :whenever_variables, -> do
  "'environment=#{fetch :whenever_environment}" \
  "&rbenv_root=#{fetch :rbenv_path}'"
end

namespace :deploy do
  desc "Migrate plugins"
  task :migrate_plugins do
    on roles(:app) do
      within "#{current_path}" do
        execute :bundle, "exec rake redmine:plugins:migrate RAILS_ENV=production"
      end
      # execute "cd '#{release_path}'; bundle exec rake redmine:plugins:migrate RAILS_ENV=production"
    end
  end
  desc "Clear prev whenever crontab"
  task :clear_whenever do
    on roles(:app) do
      execute "cd '#{capture("readlink #{current_path}")}/plugins/mail_tracker'"
    end
  end
  after "deploy:migrate", "migrate_plugins"
  before "deploy:symlink:release", "clear_whenever"
end

# Default value for :linked_files is []
append :linked_files, 'config/database.yml', 'config/secrets.yml', 'config/configuration.yml', 'config/environments/production.rb'
# Default value for linked_dirs is []
append :linked_dirs, 'log', 'tmp/pids', 'rmp/cache', 'tmp/sockets', 'public/system', 'plugins/mail_tracker/log', 'files'

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
set :keep_releases, 5
