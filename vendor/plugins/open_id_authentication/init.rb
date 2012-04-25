if Rails.version < '3'
  config.gem 'rack-openid', :lib => 'rack/openid', :version => '>=0.2.1'
end

require 'open_id_authentication'

config.middleware.use OpenIdAuthentication

config.after_initialize do
  OpenID::Util.logger = Rails.logger
  ActionController::Base.send :include, OpenIdAuthentication
end
