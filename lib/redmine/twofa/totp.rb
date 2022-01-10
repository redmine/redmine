# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require_relative 'base'

module Redmine
  module Twofa
    class Totp < Base
      def init_pairing!
        @user.update!(twofa_totp_key: ROTP::Base32.random)
        # reset the cached totp as the key might have changed
        @totp = nil
        super
      end

      def destroy_pairing_without_verify!
        @user.update!(twofa_totp_key: nil, twofa_totp_last_used_at: nil)
        # reset the cached totp as the key might have changed
        @totp = nil
        super
      end

      def verify_otp!(code)
        # topt codes are white-space-insensitive
        code = code.to_s.remove(/[[:space:]]/)
        last_verified_at = @user.twofa_totp_last_used_at
        verified_at = totp.verify(code.to_s, drift_behind: allowed_drift, after: last_verified_at)
        if verified_at
          @user.update!(twofa_totp_last_used_at: verified_at)
          true
        else
          false
        end
      end

      def provisioning_uri
        totp.provisioning_uri(@user.login)
      end

      def init_pairing_view_variables
        super.merge(
          {
            provisioning_uri: provisioning_uri,
            totp_key: @user.twofa_totp_key
          }
        )
      end

      private

      def totp
        @totp ||= ROTP::TOTP.new(@user.twofa_totp_key, issuer: Setting.host_name)
      end
    end
  end
end
