# frozen_string_literal: true

module OpenIdAuthentication
  class Nonce < ActiveRecord::Base
    self.table_name = :open_id_authentication_nonces
  end
end
