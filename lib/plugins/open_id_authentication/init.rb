# frozen_string_literal: false

require 'open_id_authentication'

config.middleware.use OpenIdAuthentication

config.after_initialize do
  OpenID::Util.logger = Rails.logger
  ActionController::Base.send :include, OpenIdAuthentication
end
