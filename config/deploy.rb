# config valid only for Capistrano 3.1
lock '3.2.1'

#role :web, %w{deployer@192.168.122.124}
#role :app, %w{deployer@192.168.122.124}
#role :db, %w{deployer@192.168.122.124}

set :application, 'pirati-redmine'
set :full_app_name, 'redmine.development.pirati.cz'
set :user, 'pirati-development-redmine'
set :repo_url, 'https://github.com/hellth/redmine.git'
set :branch, 'master'

## Application custom
set :db_config, 'database.yml'
set :rvm_ruby_string, "2.0.0@#{fetch(:application)}"
#set :application_cmd, "redmine_prod"
set :rvm_type, :user
#set :repo_url,  "https://github.com/redmine/redmine.git"
#set :branch, "master" # 2.5-stable redmine


# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call

=begin
set :ssh_options, {
    keys: %w(/home/hellth/.ssh/hellth_rsa),
    forward_agent: false,
    auth_methods: %w(publickey)
}
=end

# Default deploy_to directory is /var/www/my_app
#set :deploy_to, '/var/www/my_app'
#set :deploy_to, "/home/pirati-#{rails_env}-redmine/web/pirati-redmine"

# Default value for :scm is :git
set :scm, :git

# Default value for :format is :pretty
set :format, :pretty

# Default value for :log_level is :debug
set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for linked_dirs is []
# set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

# setup rbenv.
#set :rbenv_type, :user
#set :rbenv_ruby, '2.0.0'
#set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
#set :rbenv_map_bins, %w{rake gem bundle ruby rails}

# setup rvm
#set :rvm_type, :user                     # Defaults to: :auto
#set :rvm_ruby_version, '2.0.0@redmine'      # Defaults to: 'default'

# install rvm
#set :rvm1_ruby_version, '2.0.0'

# bundler - https://github.com/capistrano/bundler
set :bundle_gemfile, -> { release_path.join('Gemfile') }      # default: nil

# dirs we want symlinking to shared
set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system config}

# files we want symlinking to specific entries in shared.
set :linked_files, %w{config/database.yml Gemfile.local}

# what specs should be run before deployment is allowed to
# continue, see lib/capistrano/tasks/run_tests.cap
set :tests, []

# which config files should be copied by deploy:setup_config
# see documentation in lib/capistrano/tasks/setup_config.cap
# for details of operations
set(:config_files, %w(
  nginx.conf
  database.yml.example
  configuration.yml.example
  additional_environment.rb.example
  log_rotation
  unicorn.rb
  unicorn_init.sh
))

# which config files should be made executable after copying
# by deploy:setup_config
set(:executable_config_files, %w(
  unicorn_init.sh
))

# files which need to be symlinked to other parts of the
# filesystem. For example nginx virtualhosts, log rotation
# init scripts etc.
set(:symlinks, [
  {
    source: "nginx.conf",
    link: "/etc/nginx/sites-enabled/#{fetch(:full_app_name)}"
  },
  {
    source: "unicorn_init.sh",
    link: "/etc/init.d/unicorn_#{fetch(:full_app_name)}"
  },
  {
    source: "log_rotation",
   link: "/etc/logrotate.d/#{fetch(:full_app_name)}"
  }
])

=begin
namespace :rvm do
  desc "rvm rmvrc trust"
  task :trust_rvmrc do
    on roles(:app) do
      execute "rvm --create use 2.0.0@redmine"
      #run "rvm rvmrc trust #{release_path}"
    end
  end

end
=end

# this:
# http://www.capistranorb.com/documentation/getting-started/flow/
# is worth reading for a quick overview of what tasks are called
# and when for `cap stage deploy`


namespace :deploy do
  namespace :check do
    task :copy_gemfile do
      on roles(:all) do
        #template "application.yml.erb", "#{shared_path}/config/application.yml"
        upload! StringIO.new(File.read("Gemfile.local")), "#{shared_path}/Gemfile.local"
        upload! StringIO.new(File.read(".ruby-gemset")), "#{shared_path}/.ruby-gemset"
        upload! StringIO.new(File.read(".ruby-version")), "#{shared_path}/.ruby-version"
        upload! StringIO.new(File.read("config/production.database.yml")), "#{shared_path}/config/database.yml"
        #upload! StringIO.new(File.read("Gemfile.lock")), "#{shared_path}/Gemfile.lock"
      end
    end

    before :linked_files, :copy_gemfile
  end
end

desc "Deploy the site, pulls from Git, migrate the db and precompile assets, then restart Passenger."
task :deploy do
  on roles(:web), in: :sequence do
    within release_path do
      execute :git, :pull
      execute :bundle, :install, '--no-deployment'
      execute :rake, 'db:setup'
      execute :rake, 'db:migrate'
      execute :rake, 'assets:precompile'
      execute :touch, 'tmp/restart.txt'
    end
  end
end

namespace :deploy do

  desc "Restart application"
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      execute :touch, release_path.join("tmp/restart.txt")
    end
  end

  desc "Setup application - cold setup"
  task :cold_setup do
    on roles(:web), in: :sequence, wait: 5 do

      if test("[ -w #{fetch(:deploy_to)} ]")
        info "#{shared_path} is writable on #{host}"
      else
        error "#{shared_path} is not writable on #{host}"
      end

      execute :touch, shared_path.join("tmp/coldsetup.txt")
      #upload! StringIO.new(File.read("Gemfile.local")), "#{shared_path}/Gemfile.local"
      #upload! StringIO.new(File.read(".ruby-gemset")), "#{shared_path}/.ruby-gemset"
      #upload! StringIO.new(File.read(".ruby-version")), "#{shared_path}/.ruby-version"
      #upload! StringIO.new(File.read("config/production.database.yml")), "#{shared_path}/config/database.yml"
      #execute :ln, "-nfs", "#{shared_path}/config/production.database.yml", "#{release_path}/config/production.database.yml"
      execute :ls, '-alh'

=begin
      before 'deploy', 'deploy:check_write_permissions'
      before 'deploy', 'rvm:check'
      before 'deploy', 'rvm1:install:rvm'  # install/update RVM
      after 'rvm1:install:rvm', 'bundler:install'
      before 'deploy', 'deploy:cold_setup'
=end

    end
  end

  desc "Upload database.yml file."
  task :upload_yml do
    on roles(:web) do
      execute "mkdir -p #{shared_path}/config"
      upload! StringIO.new(File.read("config/production.database.yml")), "#{shared_path}/config/production.database.yml"
    end
  end

  desc "Check that we can access everything"
  task :check_write_permissions do
    on roles(:all) do |host|
      if test("[ -w #{fetch(:deploy_to)} ]")
        info "#{fetch(:deploy_to)} is writable on #{host}"
      else
        error "#{fetch(:deploy_to)} is not writable on #{host}"
      end
    end
  end

  desc "Setup bundler - first install problems with Gemfile.lock"
  task :bundler_setup
    on roles(:all) do
      info "Executing bundle from bundler_setup"
      execute :bundle, 'list'

    end

  #create rvm environment



  #before 'deploy', 'rvm1:install:ruby' # install ruby



  # https://github.com/capistrano/capistrano/issues/611
  #before  'deploy:assets:precompile', 'deploy:migrate'

=begin
  before "deploy:assets:precompile" do
      #exec :ln, "-nfs #{shared_path}/config/settings.yml #{release_path}/config/settings.yml"
      execute :touch, release_path.join("tmp/precompile_hook.txt")
  end
=end

  #before 'deploy', 'rvm:trust_rvmrc'

  # make sure we're deploying what we think we're deploying
  #before :deploy, "deploy:check_revision"
  # only allow a deploy with passing tests to deployed
  #before :deploy, "deploy:run_tests"

  before :started, 'deploy:cold_setup'
  before 'deploy:check:linked_files', 'deploy:cold_setup'


  #before 'bundler:install', 'deploy:bundler_setup'

  # compile assets locally then rsync
  #after 'deploy:symlink:shared', 'deploy:compile_assets_locally'
  after :finishing, 'deploy:cleanup'

  # remove the default nginx configuration as it will tend
  # to conflict with our configs.
  #before 'deploy:setup_config', 'nginx:remove_default_vhost'

  # reload nginx to it will pick up any modified vhosts from
  # setup_config
  #after 'deploy:setup_config', 'nginx:reload'

  # Restart monit so it will pick up any monit configurations
  # we've added
  # after 'deploy:setup_config', 'monit:restart'

  # As of Capistrano 3.1, the `deploy:restart` task is not called
  # automatically.
  #after 'deploy:publishing', 'deploy:restart'
end

=begin
task :precompile do
  on roles :web do
    within release_path do
      with rails_env: fetch(:rails_env) do
        execute :bundle, "exec rake assets:precompile"
      end
    end
  end
end
=end

#namespace :deploy do
#
#  desc 'Restart application'
#  task :restart do
#    on roles(:app), in: :sequence, wait: 5 do
#      # Your restart mechanism here, for example:
#      execute :touch, release_path.join('tmp/restart.txt')
#    end
#  end
#
#  after :publishing, :restart
#
#  after :restart, :clear_cache do
#    on roles(:web), in: :groups, limit: 3, wait: 10 do
#      # Here we can do anything such as:
#      within release_path do
#         execute :rake, 'cache:clear'
#      end
#    end
#  end
#
#end


=begin
namespace :deploy do
  desc "Make sure local git is in sync with remote."
  task :check_revision do
    on roles(:app), in: :groups do
      puts "Branch - #{branch}"
      exit
      unless `git rev-parse HEAD` == `git rev-parse origin/#{branch}`
        puts "WARNING: HEAD is not the same as origin/#{branch}"
        puts "Run `git push` to sync changes."
        exit
      end
    end
  end
end
=end
