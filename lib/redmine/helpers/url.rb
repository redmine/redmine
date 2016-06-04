# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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
      def uri_with_safe_scheme?(uri, schemes = ['http', 'https', 'ftp', 'mailto', nil])
        # URLs relative to the current document or document root (without a protocol
        # separator, should be harmless
        return true unless uri.include? ":"
    
        # Other URLs need to be parsed
        schemes.include? URI.parse(uri).scheme
      rescue URI::InvalidURIError
        false
      end
    end
  end
end
