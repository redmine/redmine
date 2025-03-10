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

require 'redmine/scm/adapters/subversion_adapter'

module Redmine
  # @private
  module VERSION
    MAJOR = 6
    MINOR = 0
    TINY  = 4

    # Branch values:
    # * official release: nil
    # * stable branch:    stable
    # * trunk:            devel
    BRANCH = 'stable'

    # Retrieves the revision from the working copy
    def self.revision
      if File.directory?(File.join(Rails.root, '.svn'))
        begin
          path = Redmine::Scm::Adapters::AbstractAdapter.shell_quote(Rails.root.to_s)
          if `#{Redmine::Scm::Adapters::SubversionAdapter.client_command} info --xml #{path}` =~ /commit\s+revision="(\d+)"/
            return $1.to_i
          end
        rescue
          # Could not find the current revision
        end
      end
      nil
    end

    REVISION = self.revision
    ARRAY    = [MAJOR, MINOR, TINY, BRANCH, REVISION].compact
    STRING   = ARRAY.join('.')

    def self.to_a; ARRAY  end
    def self.to_s; STRING end
  end
end
