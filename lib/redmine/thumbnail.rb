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

require 'fileutils'
require 'mimemagic'

module Redmine
  module Thumbnail
    extend Redmine::Utils::Shell

    CONVERT_BIN = (Redmine::Configuration['imagemagick_convert_command'] || 'convert').freeze
    ALLOWED_TYPES = %w(image/bmp image/gif image/jpeg image/png)

    # Generates a thumbnail for the source image to target
    def self.generate(source, target, size)
      return nil unless convert_available?
      unless File.exists?(target)
        # Make sure we only invoke Imagemagick if the file type is allowed
        unless File.open(source) {|f| ALLOWED_TYPES.include? MimeMagic.by_magic(f).try(:type) }
          return nil
        end
        directory = File.dirname(target)
        unless File.exists?(directory)
          FileUtils.mkdir_p directory
        end
        size_option = "#{size}x#{size}>"
        cmd = "#{shell_quote CONVERT_BIN} #{shell_quote source} -auto-orient -thumbnail #{shell_quote size_option} #{shell_quote target}"
        unless system(cmd)
          logger.error("Creating thumbnail failed (#{$?}):\nCommand: #{cmd}")
          return nil
        end
      end
      target
    end

    def self.convert_available?
      return @convert_available if defined?(@convert_available)
      begin
        `#{shell_quote CONVERT_BIN} -version`
        @convert_available = $?.success?
      rescue
        @convert_available = false
      end
      logger.warn("Imagemagick's convert binary (#{CONVERT_BIN}) not available") unless @convert_available
      @convert_available
    end

    def self.logger
      Rails.logger
    end
  end
end
