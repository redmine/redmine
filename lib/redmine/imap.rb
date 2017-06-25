# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

require 'net/imap'

module Redmine
  module IMAP
    class << self
      def check(imap_options={}, options={})
        host = imap_options[:host] || '127.0.0.1'
        port = imap_options[:port] || '143'
        ssl = !imap_options[:ssl].nil?
        starttls = !imap_options[:starttls].nil?
        folder = imap_options[:folder] || 'INBOX'

        imap = Net::IMAP.new(host, port, ssl)
        if starttls
          imap.starttls
        end
        imap.login(imap_options[:username], imap_options[:password]) unless imap_options[:username].nil?
        imap.select(folder)
        imap.uid_search(['NOT', 'SEEN']).each do |uid|
          msg = imap.uid_fetch(uid,'RFC822')[0].attr['RFC822']
          logger.debug "Receiving message #{uid}" if logger && logger.debug?
          if MailHandler.safe_receive(msg, options)
            logger.debug "Message #{uid} successfully received" if logger && logger.debug?
            if imap_options[:move_on_success]
              imap.uid_copy(uid, imap_options[:move_on_success])
            end
            imap.uid_store(uid, "+FLAGS", [:Seen, :Deleted])
          else
            logger.debug "Message #{uid} can not be processed" if logger && logger.debug?
            imap.uid_store(uid, "+FLAGS", [:Seen])
            if imap_options[:move_on_failure]
              imap.uid_copy(uid, imap_options[:move_on_failure])
              imap.uid_store(uid, "+FLAGS", [:Deleted])
            end
          end
        end
        imap.expunge
        imap.logout
        imap.disconnect
      end

      private

      def logger
        ::Rails.logger
      end
    end
  end
end
