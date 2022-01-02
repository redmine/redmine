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

require 'uri'

module Redmine
  module Helpers
    module URL
      # safe for resources fetched without user interaction?
      def uri_with_safe_scheme?(uri, schemes = ['http', 'https', 'ftp', 'mailto', nil])
        # URLs relative to the current document or document root (without a protocol
        # separator, should be harmless
        return true unless uri.to_s.include? ":"

        # Other URLs need to be parsed
        schemes.include? URI.parse(uri).scheme
      rescue URI::Error
        false
      end

      # safe to render links to given uri?
      def uri_with_link_safe_scheme?(uri)
        # regexp adapted from Sanitize (we need to catch even invalid protocol specs)
        return true unless uri =~ /\A\s*([^\/#]*?)(?:\:|&#0*58|&#x0*3a)/i

        # absolute scheme
        scheme = $1.downcase
        return false unless /\A[a-z][a-z0-9\+\.\-]*\z/.match?(scheme) # RFC 3986

        %w(data javascript vbscript).none?(scheme)
      end
    end
  end
end
