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

require 'fileutils'
require 'shellwords'
require 'tempfile'
require 'timeout'

module Redmine
  module Markdownizer
    extend Redmine::Utils::Shell

    COMMAND = (Redmine::Configuration['pandoc_command'] || 'pandoc').freeze
    MAX_SOURCE_SIZE = 20.megabytes
    MAX_PREVIEW_SIZE = 512.kilobytes

    def self.supports?(filename)
      markdownizable_extensions.include?(File.extname(filename.to_s).downcase)
    end

    def self.convert(source, target)
      return nil unless available?
      return target if File.exist?(target)

      if File.size(source) > MAX_SOURCE_SIZE
        logger.warn("Markdownized preview generation skipped because source file is too large (#{File.size(source)} bytes): #{source}")
        return nil
      end

      directory = File.dirname(target)
      FileUtils.mkdir_p(directory)
      args = [COMMAND, source, "-t", "gfm"]
      pid = nil
      output = Tempfile.new('markdownized-preview')

      begin
        Timeout.timeout(Redmine::Configuration['thumbnails_generation_timeout'].to_i) do
          pid = Process.spawn(*args, out: output.path)
          _, status = Process.wait2(pid)
          unless status.success?
            logger.error("Markdownized preview generation failed (#{status.exitstatus}):\nCommand: #{args.shelljoin}")
            return nil
          end
        end
      rescue Timeout::Error
        if pid
          Process.kill('KILL', pid)
          Process.detach(pid)
        end
        logger.error("Markdownized preview generation timed out:\nCommand: #{args.shelljoin}")
        return nil
      rescue => e
        logger.error("Markdownized preview generation failed:\nCommand: #{args.shelljoin}\nException was: #{e.message}")
        return nil
      ensure
        output.close
      end

      preview = File.binread(output.path, MAX_PREVIEW_SIZE + 1) || +""
      File.binwrite(target, preview.byteslice(0, MAX_PREVIEW_SIZE))
      target
    ensure
      output&.unlink
    end

    def self.available?
      return @available if defined?(@available)

      begin
        @pandoc_version = `#{shell_quote COMMAND} --version`[/pandoc\s+([\d.]+)/, 1].split('.').map(&:to_i)
        @available = $?.success?
      rescue
        @available = false
      end
      logger.warn("Pandoc binary (#{COMMAND}) not available") unless @available
      @available
    end

    def self.markdownizable_extensions
      return @markdownizable_extensions if defined?(@markdownizable_extensions)

      if available?
        # Microsoft Word and LibreOffice Writer files are supported by a wide
        # range of Pandoc versions
        @markdownizable_extensions = %w[.docx .odt]
      else
        return (@markdownizable_extensions = [])
      end
      # Pandoc >= 3.8.3 supports Microsoft Excel and PowerPoint files
      @markdownizable_extensions += %w[.xlsx .pptx] if (@pandoc_version <=> [3, 8, 3]) >= 0

      @markdownizable_extensions
    end

    def self.logger
      Rails.logger
    end
  end
end
