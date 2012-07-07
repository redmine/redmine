# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
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

module Redmine
  module Thumbnail
    extend Redmine::Utils::Shell

    # Generates a thumbnail for the source image to target
    def self.generate(source, target, size)
      unless File.exists?(target)
        directory = File.dirname(target)
        unless File.exists?(directory)
          FileUtils.mkdir_p directory
        end
        bin = Redmine::Configuration['imagemagick_convert_command'] || 'convert'
        size_option = "#{size}x#{size}>"
        cmd = "#{shell_quote bin} #{shell_quote source} -thumbnail #{shell_quote size_option} #{shell_quote target}"
        unless system(cmd)
          logger.error("Creating thumbnail failed (#{$?}):\nCommand: #{cmd}")
          return nil
        end
      end
      target
    end

    def self.logger
      Rails.logger
    end
  end
end
