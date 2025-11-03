# frozen_string_literal: true

require 'jwt'
require 'base64'
require 'aws-sdk-ssm'

module Redmine
  module MeruJwtAuth
    class << self
      # Get the SSM parameter name for the public key (workspace-specific)
      def ssm_public_key_parameter
        "/#{ENV['WORKSPACE']}/meru/play/http/session/public-key"
      end

      # Cache duration for the public key (1 hour)
      KEY_CACHE_DURATION = 3600

      # Get the Meru session cookie name (workspace-specific)
      def meru_session_cookie_name
        "#{ENV['WORKSPACE'].upcase}_MERU_SESSION"
      end

      # Get the Meru login URL from configuration
      def meru_login_url
        host = ENV['MERU_HOST'] || "#{ENV['WORKSPACE']}.meru.dev.minutekey.com"
        "https://#{host}/#/"
      end

      # Get the AWS region for SSM
      def aws_region
        ENV['AWS_REGION'] || 'us-east-1'
      end

      # Get the public key for JWT verification from SSM
      def public_key
        # Return cached key if still valid
        if @public_key && @key_cached_at && (Time.now - @key_cached_at) < KEY_CACHE_DURATION
          return @public_key
        end

        # Fetch from SSM
        begin
          Rails.logger.info "Fetching Meru JWT public key from SSM: #{ssm_public_key_parameter}"
          ssm_client = Aws::SSM::Client.new(region: aws_region)
          response = ssm_client.get_parameter(
            name: ssm_public_key_parameter,
            with_decryption: true
          )

          # The public key is stored as base64-encoded X.509 DER format
          key_base64 = response.parameter.value
          key_der = Base64.decode64(key_base64)

          # Create an OpenSSL key from the DER format
          @public_key = OpenSSL::PKey::EC.new(key_der)
          @key_cached_at = Time.now

          Rails.logger.info "Successfully fetched and cached Meru JWT public key from SSM"
          @public_key
        rescue Aws::SSM::Errors::ParameterNotFound => e
          Rails.logger.error "Meru JWT public key not found in SSM: #{ssm_public_key_parameter}"
          nil
        rescue => e
          Rails.logger.error "Failed to fetch Meru JWT public key from SSM: #{e.message}"
          nil
        end
      end

      # Extract JWT token from cookie value
      def extract_jwt_from_cookie(cookie_value)
        return nil if cookie_value.blank?

        # The cookie value might already be just the token, or prefixed
        # Remove the prefix if present
        token = cookie_value.to_s.sub(/^#{meru_session_cookie_name}=/, '')
        token.presence
      end

      # Verify and decode the JWT token
      def verify_jwt(token)
        return nil if token.blank?

        key = public_key
        return nil if key.nil?

        begin
          # Decode and verify the JWT with ES512 algorithm
          decoded = JWT.decode(
            token,
            key,
            true,
            {
              algorithm: 'ES512',
              verify_expiration: true
            }
          )

          # Return the payload if successful
          decoded.first
        rescue JWT::ExpiredSignature => e
          Rails.logger.info "Meru JWT expired: #{e.message}"
          nil
        rescue JWT::DecodeError => e
          Rails.logger.warn "Failed to decode Meru JWT: #{e.message}"
          nil
        rescue => e
          Rails.logger.error "Unexpected error verifying Meru JWT: #{e.message}"
          nil
        end
      end

      # Find a Redmine user from the JWT payload
      def find_user_from_jwt(payload)
        return nil if payload.blank?

        username = payload['username']
        return nil if username.blank?

        # Find the user by login
        user = User.find_by_login(username)

        if user && user.active?
          user
        else
          Rails.logger.info "User '#{username}' from Meru JWT not found or inactive in Redmine"
          nil
        end
      end

      # Main authentication method
      def authenticate_from_cookie(cookies)
        # Get the Meru session cookie
        cookie_value = cookies[meru_session_cookie_name]
        return nil if cookie_value.blank?

        # Extract the JWT token
        token = extract_jwt_from_cookie(cookie_value)
        return nil if token.blank?

        # Verify the JWT and get the payload
        payload = verify_jwt(token)
        return nil if payload.blank?

        # Find the user from the payload
        user = find_user_from_jwt(payload)

        if user
          Rails.logger.info "Successfully authenticated user '#{user.login}' via Meru JWT"
        end

        user
      end
    end
  end
end
