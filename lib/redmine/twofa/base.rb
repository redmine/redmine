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

module Redmine
  module Twofa
    class Base
      def self.inherited(child)
        # require-ing a Base subclass will register it as a 2FA scheme
        Redmine::Twofa.register_scheme(scheme_name(child), child)
      end

      def self.scheme_name(klass = self)
        klass.name.demodulize.underscore
      end

      def scheme_name
        self.class.scheme_name
      end

      def initialize(user)
        @user = user
      end

      def init_pairing!
        @user
      end

      def confirm_pairing!(code)
        # make sure an otp and not a backup code is used
        if verify_otp!(code)
          @user.update!(twofa_scheme: scheme_name)
          deliver_twofa_paired
          return true
        else
          return false
        end
      end

      def deliver_twofa_paired
        ::Mailer.deliver_security_notification(
          @user,
          User.current,
          {
            title: :label_my_account,
            message: 'twofa_mail_body_security_notification_paired',
            # (mis-)use field here as value wouldn't get localized
            field: "twofa__#{scheme_name}__name",
            url: {controller: 'my', action: 'account'}
          }
        )
      end

      def destroy_pairing!(code)
        if verify!(code)
          destroy_pairing_without_verify!
          return true
        else
          return false
        end
      end

      def destroy_pairing_without_verify!
        @user.update!(twofa_scheme: nil)
        backup_codes.delete_all
        deliver_twofa_unpaired
      end

      def deliver_twofa_unpaired
        ::Mailer.deliver_security_notification(
          @user,
          User.current,
          {
            title: :label_my_account,
            message: 'twofa_mail_body_security_notification_unpaired',
            url: {controller: 'my', action: 'account'}
          }
        )
      end

      def send_code(controller: nil, action: nil)
        # return true only if the scheme sends a code to the user
        false
      end

      def verify!(code)
        verify_otp!(code) || verify_backup_code!(code)
      end

      def verify_otp!(code)
        raise 'not implemented'
      end

      def verify_backup_code!(code)
        # backup codes are case-insensitive and white-space-insensitive
        code = code.to_s.remove(/[[:space:]]/).downcase
        user_from_code = Token.find_active_user('twofa_backup_code', code)
        # invalidate backup code after usage
        Token.where(user_id: @user.id).find_token('twofa_backup_code', code).try(:delete)
        # make sure the user using the backup code is the same it's been issued to
        return false unless @user.present? && @user == user_from_code

        ::Mailer.deliver_security_notification(
          @user,
          User.current,
          {
            originator: @user,
            title: :label_my_account,
            message: 'twofa_mail_body_backup_code_used',
            url: {controller: 'my', action: 'account'}
          }
        )
        return true
      end

      def init_backup_codes!
        backup_codes.delete_all
        tokens = []
        10.times do
          token = Token.create(user_id: @user.id, action: 'twofa_backup_code')
          token.update_columns value: Redmine::Utils.random_hex(6)
          tokens << token
        end
        ::Mailer.deliver_security_notification(
          @user,
          User.current,
          {
            title: :label_my_account,
            message: 'twofa_mail_body_backup_codes_generated',
            url: {controller: 'my', action: 'account'}
          }
        )
        tokens
      end

      def backup_codes
        Token.where(user_id: @user.id, action: 'twofa_backup_code')
      end

      # this will only be used on pairing initialization
      def init_pairing_view_variables
        otp_confirm_view_variables
      end

      def otp_confirm_view_variables
        {
          scheme_name: scheme_name,
          resendable: false
        }
      end

      private

      def allowed_drift
        30
      end
    end
  end
end
