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
  module CodesetUtil
    def self.replace_invalid_utf8(str)
      return nil if str.nil?

      str = str.dup
      str.force_encoding('UTF-8')
      unless str.valid_encoding?
        str = str.encode("UTF-16LE", :invalid => :replace,
              :undef => :replace, :replace => '?').encode("UTF-8")
      end
      str
    end

    def self.to_utf8(str, encoding)
      return if str.nil?

      str = str.b
      if str.empty?
        str.force_encoding("UTF-8")
        return str
      end
      enc = encoding.blank? ? "UTF-8" : encoding
      if enc.casecmp("UTF-8") != 0
        str.force_encoding(enc)
        str = str.encode("UTF-8", :invalid => :replace,
              :undef => :replace, :replace => '?')
      else
        str = replace_invalid_utf8(str)
      end
      str
    end

    def self.to_utf8_by_setting(str)
      return if str.nil?

      str = str.dup
      self.to_utf8_by_setting_internal(str).force_encoding('UTF-8')
    end

    def self.to_utf8_by_setting_internal(str)
      return if str.nil?

      str = str.b
      return str if str.empty?
      return str if /\A[\r\n\t\x20-\x7e]*\Z/n.match?(str) # for us-ascii

      str.force_encoding('UTF-8')
      encodings = Setting.repositories_encodings.split(',').collect(&:strip)
      encodings.each do |encoding|
        begin
          str.force_encoding(encoding)
          utf8 = str.encode('UTF-8')
          return utf8 if utf8.valid_encoding?
        rescue
          # do nothing here and try the next encoding
        end
      end
      self.replace_invalid_utf8(str).force_encoding('UTF-8')
    end

    def self.from_utf8(str, encoding)
      return if str.nil?

      str = str.dup
      str ||= ''
      str.force_encoding('UTF-8')
      if encoding.casecmp('UTF-8') != 0
        str = str.encode(encoding, :invalid => :replace,
                         :undef => :replace, :replace => '?')
      else
        str = self.replace_invalid_utf8(str)
      end
    end

    def self.guess_encoding(str)
      return if str.nil?

      str = str.dup
      encodings = Setting.repositories_encodings.split(',').collect(&:strip)
      encodings = encodings.presence || ['UTF-8']

      encodings.each do |encoding|
        begin
          str.force_encoding(encoding)
        rescue Encoding::ConverterNotFoundError
          # ignore if the encoding name is invalid
        end
        return encoding if str.valid_encoding?
      end
      nil
    end
  end
end
