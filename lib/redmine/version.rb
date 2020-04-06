# frozen_string_literal: true

require 'redmine/scm/adapters/subversion_adapter'

module Redmine
  # @private
  module VERSION
    MAJOR = 4
    MINOR = 1
    TINY  = 1

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
