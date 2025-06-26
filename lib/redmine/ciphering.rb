# frozen_string_literal: true

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

module Redmine
  module Ciphering
    def self.included(base)
      base.extend ClassMethods
    end

    class << self
      def encrypt_text(text)
        if cipher_key.blank? || text.blank?
          text
        else
          c = OpenSSL::Cipher.new("aes-256-cbc")
          iv = c.random_iv
          c.encrypt
          c.key = cipher_key
          c.iv = iv
          e = c.update(text.to_s)
          e << c.final
          "aes-256-cbc:" + [e, iv].map {|v| Base64.strict_encode64(v)}.join('--')
        end
      end

      def decrypt_text(text)
        if text && match = text.match(/\Aaes-256-cbc:(.+)\Z/)
          if cipher_key.blank?
            logger.error "Attempt to decrypt a ciphered text with no cipher key configured in config/configuration.yml" if logger
            return text
          end
          text = match[1]
          c = OpenSSL::Cipher.new("aes-256-cbc")
          e, iv = text.split("--").map {|s| Base64.decode64(s)}
          c.decrypt
          c.key = cipher_key
          c.iv = iv
          d = c.update(e)
          d << c.final
        else
          text
        end
      end

      def cipher_key
        key = Redmine::Configuration['database_cipher_key'].to_s
        key.blank? ? nil : Digest::SHA256.hexdigest(key)[0..31]
      end

      def logger
        Rails.logger
      end
    end

    module ClassMethods
      def encrypt_all(attribute)
        transaction do
          all.each do |object|
            clear = object.send(attribute)
            object.send "#{attribute}=", clear
            raise(ActiveRecord::Rollback) unless object.save(validate: false)
          end
        end ? true : false
      end

      def decrypt_all(attribute)
        transaction do
          all.each do |object|
            clear = object.send(attribute)
            object.send :write_attribute, attribute, clear
            raise(ActiveRecord::Rollback) unless object.save(validate: false)
          end
        end ? true : false
      end
    end

    private

    # Returns the value of the given ciphered attribute
    def read_ciphered_attribute(attribute)
      Redmine::Ciphering.decrypt_text(read_attribute(attribute))
    end

    # Sets the value of the given ciphered attribute
    def write_ciphered_attribute(attribute, value)
      write_attribute(attribute, Redmine::Ciphering.encrypt_text(value))
    end
  end
end
