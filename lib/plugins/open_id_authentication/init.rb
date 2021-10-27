# frozen_string_literal: false

require File.dirname(__FILE__) + '/lib/open_id_authentication'

config.middleware.use OpenIdAuthentication

config.after_initialize do
  OpenID::Util.logger = Rails.logger
  ActionController::Base.send :include, OpenIdAuthentication
end
