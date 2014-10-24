# Simple Role Syntax
# ==================
# Supports bulk-adding hosts to roles, the primary server in each group
# is considered to be the first unless any hosts have the primary
# property set.  Don't declare `role :all`, it's a meta role.

#role :app, %w{deployer@192.168.122.124}
#role :web, %w{deployer@192.168.122.124}
#role :db,  %w{deployer@192.168.122.124}


# Extended Server Syntax
# ======================
# This can be used to drop a more detailed server definition into the
# server list. The second argument is a, or duck-types, Hash and is
# used to set extended properties on the server.

server '192.168.122.124', user: 'pirati-development-redmine', roles: %w{web app db}, port: 10022

set :user, 'pirati-development-redmine'
set :application, 'pirati-development-redmine'
set :full_app_name, 'redmine.development.pirati.cz'
set :rails_env, "development"
set :development
set :deploy_to, "/home/#{user}/#{rails_env}/redmine"
set :db_config, 'development.database.yml'


# Custom SSH Options
# ==================
# You may pass any option but keep in mind that net/ssh understands a
# limited set of options, consult[net/ssh documentation](http://net-ssh.github.io/net-ssh/classes/Net/SSH.html#method-c-start).
#
# Global options
# --------------
#  set :ssh_options, {
#    keys: %w(/home/hellth/.ssh/hellth_rsa),
#    forward_agent: false,
#    auth_methods: %w(publickey)
#  }
#
# And/or per server (overrides global)
# ------------------------------------
# server 'example.com',
#   user: 'user_name',
#   roles: %w{web app},
#   ssh_options: {
#     user: 'user_name', # overrides user setting above
#     keys: %w(/home/user_name/.ssh/id_rsa),
#     forward_agent: false,
#     auth_methods: %w(publickey password)
#     # password: 'please use keys'
#   }
