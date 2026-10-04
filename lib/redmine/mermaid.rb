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

require 'digest/sha2'
require 'net/http'
require 'zlib'

module Redmine
  # Rendering of Mermaid code blocks with Mermaid.js.
  #
  # Mermaid.js is not bundled with Redmine. Administrators install it with
  # `bin/rails redmine:mermaid:install`, which places dist/mermaid.min.js from
  # the mermaid npm package into vendor/javascript, one of Propshaft's load
  # paths. Diagram rendering is enabled whenever that file exists. The task
  # installs the version of Mermaid.js given by VERSION and verifies its
  # checksum. The file is not verified afterwards; if a different version is
  # found there later, it is still used and a warning is logged.
  module Mermaid
    # Version installed by the redmine:mermaid:install task
    VERSION = '12.0.0'
    # SHA-256 of dist/mermaid.min.js in the mermaid npm package
    SHA256 = '28fca7ae6ebc7ed7bb63bde63136a74bfef14f296a57e403657eeb8b32836073'
    TARBALL_URL = "https://registry.npmjs.org/mermaid/-/mermaid-#{VERSION}.tgz"
    TARBALL_ENTRY = 'package/dist/mermaid.min.js'
    FILENAME = 'mermaid.min.js'
    # Matches the version string that mermaid builds embed for mermaid's
    # getVersion function, e.g. `a={version:"12.0.0"},b=i(()=>a.version,"getVersion")`
    VERSION_REGEXP = /version:\s*"(\d+\.\d+\.\d+[\w.+-]*)"\s*\}[^"]{0,120}"getVersion"/

    class Error < StandardError; end

    class << self
      # Path of the installed file.
      def path
        Rails.root.join('vendor/javascript', FILENAME)
      end

      # Expected SHA-256 of the file to install. Stubbable for tests.
      def checksum
        SHA256
      end

      # Returns true if Mermaid.js is installed. The result is cached until
      # #reset is called.
      def available?
        return @available if defined?(@available)

        @available = path.file?
        warn_version_mismatch if @available && installed_version != VERSION
        @available
      end

      # Returns the version of the installed Mermaid.js as embedded in the
      # file, or nil if Mermaid.js is not installed or its version cannot be
      # determined. The result is cached until #reset is called.
      def installed_version
        return @installed_version if defined?(@installed_version)

        @installed_version =
          begin
            File.binread(path)[VERSION_REGEXP, 1]
          rescue SystemCallError
            nil
          end
      end

      def reset
        remove_instance_variable(:@available) if defined?(@available)
        remove_instance_variable(:@installed_version) if defined?(@installed_version)
      end

      # Installs mermaid.min.js and returns its path.
      #
      # +source+ is a local path to the mermaid npm tarball. When nil, the
      # tarball is downloaded from TARBALL_URL. Raises Redmine::Mermaid::Error
      # on failure, including when the checksum of mermaid.min.js in the
      # tarball does not match SHA256.
      def install(source: nil)
        content = source ? read_local(source) : download(TARBALL_URL)
        verify!(content)
        # Written atomically so that a partially written file is never served.
        File.atomic_write(path) {|f| f.write(content)}
        reset
        path
      end

      def uninstall
        FileUtils.rm_f(path)
        reset
      end

      private

      def warn_version_mismatch
        Rails.logger.warn(
          "Mermaid.js #{installed_version || '(unknown version)'} is installed at #{path}, " \
          "which is not the version installed by default (#{VERSION}). " \
          "Run 'bin/rails redmine:mermaid:install' to install Mermaid.js #{VERSION}."
        )
      end

      def verify!(content)
        digest = Digest::SHA256.hexdigest(content)
        return if digest == checksum

        raise Error, "checksum mismatch: expected #{checksum} (Mermaid.js #{VERSION}), got #{digest}"
      end

      def read_local(source)
        extract(File.binread(source))
      rescue SystemCallError => e
        raise Error, "cannot read #{source}: #{e.message}"
      end

      def download(url, redirects_left = 5)
        raise Error, "too many redirects while downloading #{url}" if redirects_left.zero?

        uri = URI.parse(url)
        response =
          Net::HTTP.start(
            uri.host, uri.port,
            use_ssl: uri.scheme == 'https', open_timeout: 15, read_timeout: 120
          ) do |http|
            http.get(uri.request_uri)
          end
        case response
        when Net::HTTPSuccess
          extract(response.body)
        when Net::HTTPRedirection
          download(URI.join(url, response['location']).to_s, redirects_left - 1)
        else
          raise Error, "download of #{url} failed: #{response.code} #{response.message}"
        end
      rescue SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError => e
        raise Error, "download of #{url} failed: #{e.message}"
      end

      def extract(tarball)
        require 'rubygems/package'

        Zlib::GzipReader.wrap(StringIO.new(tarball)) do |gz|
          Gem::Package::TarReader.new(gz) do |tar|
            tar.each do |entry|
              return entry.read if entry.full_name == TARBALL_ENTRY
            end
          end
        end
        raise Error, "#{TARBALL_ENTRY} not found in the tarball"
      rescue Zlib::Error, Gem::Package::TarInvalidError => e
        raise Error, "cannot read the tarball: #{e.message}"
      end
    end
  end
end
