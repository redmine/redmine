# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2020  Jean-Philippe Lang
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
        # make sure an otp is used
        if verify_otp!(code)
          @user.update!(twofa_scheme: scheme_name)
          deliver_twofa_paired
          return true
        else
          return false
        end
      end

      def deliver_twofa_paired
        Mailer.security_notification(
          @user,
          User.current,
          {
            title: :label_my_account,
            message: 'twofa_mail_body_security_notification_paired',
            # (mis-)use field here as value wouldn't get localized
            field: "twofa__#{scheme_name}__name",
            url: { controller: 'my', action: 'account' }
          }
        ).deliver
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
        deliver_twofa_unpaired
      end

      def deliver_twofa_unpaired
        Mailer.security_notification(
          @user,
          User.current,
          {
            title: :label_my_account,
            message: 'twofa_mail_body_security_notification_unpaired',
            url: { controller: 'my', action: 'account' }
          }
        ).deliver
      end

      def send_code(controller: nil, action: nil)
        # return true only if the scheme sends a code to the user
        false
      end

      def verify!(code)
        verify_otp!(code)
      end

      def verify_otp!(code)
        raise 'not implemented'
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
