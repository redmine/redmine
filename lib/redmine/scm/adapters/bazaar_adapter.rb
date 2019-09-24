# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

require 'redmine/scm/adapters/abstract_adapter'

module Redmine
  module Scm
    module Adapters
      class BazaarAdapter < AbstractAdapter

        # Bazaar executable name
        BZR_BIN = Redmine::Configuration['scm_bazaar_command'] || "bzr"

        class << self
          def client_command
            @@bin    ||= BZR_BIN
          end

          def sq_bin
            @@sq_bin ||= shell_quote_command
          end

          def client_version
            @@client_version ||= (scm_command_version || [])
          end

          def client_available
            !client_version.empty?
          end

          def scm_command_version
            scm_version = scm_version_from_command_line.b
            if m = scm_version.match(%r{\A(.*?)((\d+\.)+\d+)})
              m[2].scan(%r{\d+}).collect(&:to_i)
            end
          end

          def scm_version_from_command_line
            shellout("#{sq_bin} --version") { |io| io.read }.to_s
          end
        end

        def initialize(url, root_url=nil, login=nil, password=nil, path_encoding=nil)
          @url = url
          @root_url = url
          @path_encoding = 'UTF-8'
          # do not call *super* for non ASCII repository path
        end

        def bzr_path_encodig=(encoding)
          @path_encoding = encoding
        end

        # Get info about the repository
        def info
          cmd_args = %w|revno|
          cmd_args << bzr_target('')
          info = nil
          scm_cmd(*cmd_args) do |io|
            if io.read =~ %r{^(\d+)\r?$}
              info = Info.new({:root_url => url,
                               :lastrev => Revision.new({
                                 :identifier => $1
                               })
                             })
            end
          end
          info
        rescue ScmCommandAborted
          return nil
        end

        # Returns an Entries collection
        # or nil if the given path doesn't exist in the repository
        def entries(path=nil, identifier=nil, options={})
          path ||= ''
          entries = Entries.new
          identifier = -1 unless identifier && identifier.to_i > 0
          cmd_args = %w|ls -v --show-ids|
          cmd_args << "-r#{identifier.to_i}"
          cmd_args << bzr_target(path)
          scm_cmd(*cmd_args) do |io|
            prefix_utf8 = "#{url}/#{path}".tr('\\', '/')
            logger.debug "PREFIX: #{prefix_utf8}"
            prefix = scm_iconv(@path_encoding, 'UTF-8', prefix_utf8).b
            re = %r{^V\s+(#{Regexp.escape(prefix)})?(\/?)([^\/]+)(\/?)\s+(\S+)\r?$}
            io.each_line do |line|
              next unless line =~ re
              name_locale, slash, revision = $3.strip, $4, $5.strip
              name = scm_iconv('UTF-8', @path_encoding, name_locale)
              entries << Entry.new({:name => name,
                                    :path => ((path.empty? ? "" : "#{path}/") + name),
                                    :kind => (slash.blank? ? 'file' : 'dir'),
                                    :size => nil,
                                    :lastrev => Revision.new(:revision => revision)
                                  })
            end
          end
          if logger && logger.debug?
            logger.debug("Found #{entries.size} entries in the repository for #{target(path)}")
          end
          entries.sort_by_name
        rescue ScmCommandAborted
          return nil
        end

        def revisions(path=nil, identifier_from=nil, identifier_to=nil, options={})
          path ||= ''
          identifier_from = (identifier_from and identifier_from.to_i > 0) ? identifier_from.to_i : 'last:1'
          identifier_to = (identifier_to and identifier_to.to_i > 0) ? identifier_to.to_i : 1
          revisions = Revisions.new
          cmd_args = %w|log -v --show-ids|
          cmd_args << "-r#{identifier_to}..#{identifier_from}"
          cmd_args << bzr_target(path)
          scm_cmd(*cmd_args) do |io|
            revision = nil
            parsing  = nil
            io.each_line do |line|
              if line =~ /^----/
                revisions << revision if revision
                revision = Revision.new(:paths => [], :message => '')
                parsing = nil
              else
                next unless revision
                if line =~ /^revno: (\d+)($|\s\[merge\]$)/
                  revision.identifier = $1.to_i
                elsif line =~ /^committer: (.+)$/
                  revision.author = $1.strip
                elsif line =~ /^revision-id:(.+)$/
                  revision.scmid = $1.strip
                elsif line =~ /^timestamp: (.+)$/
                  revision.time = Time.parse($1).localtime
                elsif line =~ /^    -----/
                  # partial revisions
                  parsing = nil unless parsing == 'message'
                elsif line =~ /^(message|added|modified|removed|renamed):/
                  parsing = $1
                elsif line =~ /^  (.*)$/
                  if parsing == 'message'
                    revision.message += "#{$1}\n"
                  else
                    if $1 =~ /^(.*)\s+(\S+)$/
                      path_locale = $1.strip
                      path = scm_iconv('UTF-8', @path_encoding, path_locale)
                      revid = $2
                      case parsing
                      when 'added'
                        revision.paths << {:action => 'A', :path => "/#{path}", :revision => revid}
                      when 'modified'
                        revision.paths << {:action => 'M', :path => "/#{path}", :revision => revid}
                      when 'removed'
                        revision.paths << {:action => 'D', :path => "/#{path}", :revision => revid}
                      when 'renamed'
                        new_path = path.split('=>').last
                        if new_path
                          revision.paths << {:action => 'M', :path => "/#{new_path.strip}",
                                             :revision => revid}
                        end
                      end
                    end
                  end
                else
                  parsing = nil
                end
              end
            end
            revisions << revision if revision
          end
          revisions
        rescue ScmCommandAborted
          return nil
        end

        def diff(path, identifier_from, identifier_to=nil)
          path ||= ''
          if identifier_to
            identifier_to = identifier_to.to_i
          else
            identifier_to = identifier_from.to_i - 1
          end
          if identifier_from
            identifier_from = identifier_from.to_i
          end
          diff = []
          cmd_args = %w|diff|
          cmd_args << "-r#{identifier_to}..#{identifier_from}"
          cmd_args << bzr_target(path)
          scm_cmd_no_raise(*cmd_args) do |io|
            io.each_line do |line|
              diff << line
            end
          end
          diff
        end

        def cat(path, identifier=nil)
          cat = nil
          cmd_args = %w|cat|
          cmd_args << "-r#{identifier.to_i}" if identifier && identifier.to_i > 0
          cmd_args << bzr_target(path)
          scm_cmd(*cmd_args) do |io|
            io.binmode
            cat = io.read
          end
          cat
        rescue ScmCommandAborted
          return nil
        end

        def annotate(path, identifier=nil)
          blame = Annotate.new
          cmd_args = %w|annotate -q --all|
          cmd_args << "-r#{identifier.to_i}" if identifier && identifier.to_i > 0
          cmd_args << bzr_target(path)
          scm_cmd(*cmd_args) do |io|
            author     = nil
            identifier = nil
            io.each_line do |line|
              next unless line =~ %r{^(\d+) ([^|]+)\| (.*)$}
              rev = $1
              blame.add_line($3.rstrip,
                 Revision.new(
                  :identifier => rev,
                  :revision   => rev,
                  :author     => $2.strip
                  ))
            end
          end
          blame
        rescue ScmCommandAborted
          return nil
        end

        def self.branch_conf_path(path)
          return if path.nil?
          m = path.match(%r{^(.*[/\\])\.bzr.*$})
          bcp = (m ? m[1] : path).gsub(%r{[\/\\]$}, "")
          File.join(bcp, ".bzr", "branch", "branch.conf")
        end

        def append_revisions_only
          return @aro unless @aro.nil?
          @aro = false
          bcp = self.class.branch_conf_path(url)
          if bcp && File.exist?(bcp)
            begin
              f = File.open(bcp, "r")
              cnt = 0
              f.each_line do |line|
                l = line.chomp.to_s
                if l =~ /^\s*append_revisions_only\s*=\s*(\w+)\s*$/
                  str_aro = $1
                  if str_aro.casecmp("TRUE") == 0
                    @aro = true
                    cnt += 1
                  elsif str_aro.casecmp("FALSE") == 0
                    @aro = false
                    cnt += 1
                  end
                  if cnt > 1
                    @aro = false
                    break
                  end
                end
              end
            ensure
              f.close
            end
          end
          @aro
        end

        def scm_cmd(*args, &block)
          full_args = []
          full_args += args
          full_args_locale = []
          full_args.map do |e|
            full_args_locale << scm_iconv(@path_encoding, 'UTF-8', e)
          end
          ret = shellout(
                   self.class.sq_bin + ' ' +
                     full_args_locale.map { |e| shell_quote e.to_s }.join(' '),
                   &block
                   )
          if $? && $?.exitstatus != 0
            raise ScmCommandAborted, "bzr exited with non-zero status: #{$?.exitstatus}"
          end
          ret
        end
        private :scm_cmd

        def scm_cmd_no_raise(*args, &block)
          full_args = []
          full_args += args
          full_args_locale = []
          full_args.map do |e|
            full_args_locale << scm_iconv(@path_encoding, 'UTF-8', e)
          end
          ret = shellout(
                   self.class.sq_bin + ' ' +
                     full_args_locale.map { |e| shell_quote e.to_s }.join(' '),
                   &block
                   )
          ret
        end
        private :scm_cmd_no_raise

        def bzr_target(path)
          target(path, false)
        end
        private :bzr_target
      end
    end
  end
end
