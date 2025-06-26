# frozen_string_literal: false

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
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

require 'net/pop'

module Redmine
  module POP3
    class << self
      def check(pop_options={}, options={})
        if pop_options[:ssl]
          ssl = true
          if pop_options[:ssl] == 'force'
            Net::POP3.enable_ssl(OpenSSL::SSL::VERIFY_NONE)
          else
            Net::POP3.enable_ssl(OpenSSL::SSL::VERIFY_PEER)
          end
        else
          ssl = false
        end

        host = pop_options[:host] || '127.0.0.1'
        port = pop_options[:port]
        port ||= ssl ? '995' : '110'
        apop = (pop_options[:apop].to_s == '1')
        delete_unprocessed = (pop_options[:delete_unprocessed].to_s == '1')

        pop = Net::POP3.APOP(apop).new(host,port)
        logger.debug "Connecting to #{host}..." if logger && logger.debug?
        pop.start(pop_options[:username], pop_options[:password]) do |pop_session|
          if pop_session.mails.empty?
            logger.debug "No email to process" if logger && logger.debug?
          else
            logger.debug "#{pop_session.mails.size} email(s) to process..." if logger && logger.debug?
            pop_session.each_mail do |msg|
              message = msg.pop
              message_id = (message =~ /^Message-I[dD]: (.*)/ ? $1 : '').strip
              if MailHandler.safe_receive(message, options)
                msg.delete
                logger.debug "--> Message #{message_id} processed and deleted from the server" if logger && logger.debug?
              else
                if delete_unprocessed
                  msg.delete
                  logger.debug "--> Message #{message_id} NOT processed and deleted from the server" if logger && logger.debug?
                else
                  logger.debug "--> Message #{message_id} NOT processed and left on the server" if logger && logger.debug?
                end
              end
            end
          end
        end
      end

      private

      def logger
        ::Rails.logger
      end
    end
  end
end
