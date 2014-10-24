# Simple Role Syntax
# ==================
# Supports bulk-adding hosts to roles, the primary server in each group
# is considered to be the first unless any hosts have the primary
# property set.  Don't declare `role :all`, it's a meta role.

#role :web, %w{deployer@192.168.122.124}
#role :app, %w{deployer@192.168.122.124}
#role :db,  %w{deployer@192.168.122.124}


# Extended Server Syntax
# ======================
# This can be used to drop a more detailed server definition into the
# server list. The second argument is a, or duck-types, Hash and is
# used to set extended properties on the server.

server '192.168.122.124', user: 'deployer', roles: %w{web app db}, port: 10022, primary: true

set :user, 'pirati-production-redmine'
set :application, 'pirati-production-redmine'
set :full_app_name, 'redmine.production.pirati.cz'
set :rails_env, "production"
set :production
set :deploy_to, "/home/#{user}/#{rails_env}/redmine"
set :db_config, 'production.database.yml'

# Custom SSH Options
# ==================
# You may pass any option but keep in mind that net/ssh understands a
# limited set of options, consult[net/ssh documentation](http://net-ssh.github.io/net-ssh/classes/Net/SSH.html#method-c-start).
#
# Global options
# --------------
#  set :ssh_options, {
#    keys: %w(/home/rlisowski/.ssh/id_rsa),
#    forward_agent: false,
#    auth_methods: %w(password)
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
