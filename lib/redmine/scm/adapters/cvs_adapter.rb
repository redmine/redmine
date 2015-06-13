# redMine - project management software
# Copyright (C) 2006-2007  Jean-Philippe Lang
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
      class CvsAdapter < AbstractAdapter

        # CVS executable name
        CVS_BIN = Redmine::Configuration['scm_cvs_command'] || "cvs"

        class << self
          def client_command
            @@bin    ||= CVS_BIN
          end

          def sq_bin
            @@sq_bin ||= shell_quote_command
          end

          def client_version
            @@client_version ||= (scm_command_version || [])
          end

          def client_available
            client_version_above?([1, 12])
          end

          def scm_command_version
            scm_version = scm_version_from_command_line.dup.force_encoding('ASCII-8BIT')
            if m = scm_version.match(%r{\A(.*?)((\d+\.)+\d+)}m)
              m[2].scan(%r{\d+}).collect(&:to_i)
            end
          end

          def scm_version_from_command_line
            shellout("#{sq_bin} --version") { |io| io.read }.to_s
          end
        end

        # Guidelines for the input:
        #  url      -> the project-path, relative to the cvsroot (eg. module name)
        #  root_url -> the good old, sometimes damned, CVSROOT
        #  login    -> unnecessary
        #  password -> unnecessary too
        def initialize(url, root_url=nil, login=nil, password=nil,
                       path_encoding=nil)
          @path_encoding = path_encoding.blank? ? 'UTF-8' : path_encoding
          @url      = url
          # TODO: better Exception here (IllegalArgumentException)
          raise CommandFailed if root_url.blank?
          @root_url  = root_url

          # These are unused.
          @login    = login if login && !login.empty?
          @password = (password || "") if @login
        end

        def path_encoding
          @path_encoding
        end

        def info
          logger.debug "<cvs> info"
          Info.new({:root_url => @root_url, :lastrev => nil})
        end

        def get_previous_revision(revision)
          CvsRevisionHelper.new(revision).prevRev
        end

        # Returns an Entries collection
        # or nil if the given path doesn't exist in the repository
        # this method is used by the repository-browser (aka LIST)
        def entries(path=nil, identifier=nil, options={})
          logger.debug "<cvs> entries '#{path}' with identifier '#{identifier}'"
          path_locale = scm_iconv(@path_encoding, 'UTF-8', path)
          path_locale.force_encoding("ASCII-8BIT")
          entries = Entries.new
          cmd_args = %w|-q rls -e|
          cmd_args << "-D" << time_to_cvstime_rlog(identifier) if identifier
          cmd_args << path_with_proj(path)
          scm_cmd(*cmd_args) do |io|
            io.each_line() do |line|
              fields = line.chop.split('/',-1)
              logger.debug(">>InspectLine #{fields.inspect}")
              if fields[0]!="D"
                time = nil
                # Thu Dec 13 16:27:22 2007
                time_l = fields[-3].split(' ')
                if time_l.size == 5 && time_l[4].length == 4
                  begin
                    time = Time.parse(
                             "#{time_l[1]} #{time_l[2]} #{time_l[3]} GMT #{time_l[4]}")
                  rescue
                  end
                end
                entries << Entry.new(
                 {
                  :name => scm_iconv('UTF-8', @path_encoding, fields[-5]),
                  #:path => fields[-4].include?(path)?fields[-4]:(path + "/"+ fields[-4]),
                  :path => scm_iconv('UTF-8', @path_encoding, "#{path_locale}/#{fields[-5]}"),
                  :kind => 'file',
                  :size => nil,
                  :lastrev => Revision.new(
                      {
                        :revision => fields[-4],
                        :name     => scm_iconv('UTF-8', @path_encoding, fields[-4]),
                        :time     => time,
                        :author   => ''
                      })
                  })
              else
                entries << Entry.new(
                 {
                  :name    => scm_iconv('UTF-8', @path_encoding, fields[1]),
                  :path    => scm_iconv('UTF-8', @path_encoding, "#{path_locale}/#{fields[1]}"),
                  :kind    => 'dir',
                  :size    => nil,
                  :lastrev => nil
                 })
              end
            end
          end
          entries.sort_by_name
        rescue ScmCommandAborted
          nil
        end

        STARTLOG="----------------------------"
        ENDLOG  ="============================================================================="

        # Returns all revisions found between identifier_from and identifier_to
        # in the repository. both identifier have to be dates or nil.
        # these method returns nothing but yield every result in block
        def revisions(path=nil, identifier_from=nil, identifier_to=nil, options={}, &block)
          path_with_project_utf8   = path_with_proj(path)
          path_with_project_locale = scm_iconv(@path_encoding, 'UTF-8', path_with_project_utf8)
          logger.debug "<cvs> revisions path:" +
              "'#{path}',identifier_from #{identifier_from}, identifier_to #{identifier_to}"
          cmd_args = %w|-q rlog|
          cmd_args << "-d" << ">#{time_to_cvstime_rlog(identifier_from)}" if identifier_from
          cmd_args << path_with_project_utf8
          scm_cmd(*cmd_args) do |io|
            state      = "entry_start"
            commit_log = String.new
            revision   = nil
            date       = nil
            author     = nil
            entry_path = nil
            entry_name = nil
            file_state = nil
            branch_map = nil
            io.each_line() do |line|
              if state != "revision" && /^#{ENDLOG}/ =~ line
                commit_log = String.new
                revision   = nil
                state      = "entry_start"
              end
              if state == "entry_start"
                branch_map = Hash.new
                if /^RCS file: #{Regexp.escape(root_url_path)}\/#{Regexp.escape(path_with_project_locale)}(.+),v$/ =~ line
                  entry_path = normalize_cvs_path($1)
                  entry_name = normalize_path(File.basename($1))
                  logger.debug("Path #{entry_path} <=> Name #{entry_name}")
                elsif /^head: (.+)$/ =~ line
                  entry_headRev = $1 #unless entry.nil?
                elsif /^symbolic names:/ =~ line
                  state = "symbolic" #unless entry.nil?
                elsif /^#{STARTLOG}/ =~ line
                  commit_log = String.new
                  state      = "revision"
                end
                next
              elsif state == "symbolic"
                if /^(.*):\s(.*)/ =~ (line.strip)
                  branch_map[$1] = $2
                else
                  state = "tags"
                  next
                end
              elsif state == "tags"
                if /^#{STARTLOG}/ =~ line
                  commit_log = ""
                  state = "revision"
                elsif /^#{ENDLOG}/ =~ line
                  state = "head"
                end
                next
              elsif state == "revision"
                if /^#{ENDLOG}/ =~ line || /^#{STARTLOG}/ =~ line
                  if revision
                    revHelper = CvsRevisionHelper.new(revision)
                    revBranch = "HEAD"
                    branch_map.each() do |branch_name, branch_point|
                      if revHelper.is_in_branch_with_symbol(branch_point)
                        revBranch = branch_name
                      end
                    end
                    logger.debug("********** YIELD Revision #{revision}::#{revBranch}")
                    yield Revision.new({
                      :time    => date,
                      :author  => author,
                      :message => commit_log.chomp,
                      :paths => [{
                        :revision => revision.dup,
                        :branch   => revBranch.dup,
                        :path     => scm_iconv('UTF-8', @path_encoding, entry_path),
                        :name     => scm_iconv('UTF-8', @path_encoding, entry_name),
                        :kind     => 'file',
                        :action   => file_state
                           }]
                         })
                  end
                  commit_log = String.new
                  revision   = nil
                  if /^#{ENDLOG}/ =~ line
                    state = "entry_start"
                  end
                  next
                end

                if /^branches: (.+)$/ =~ line
                  # TODO: version.branch = $1
                elsif /^revision (\d+(?:\.\d+)+).*$/ =~ line
                  revision = $1
                elsif /^date:\s+(\d+.\d+.\d+\s+\d+:\d+:\d+)/ =~ line
                  date       = Time.parse($1)
                  line_utf8    = scm_iconv('UTF-8', options[:log_encoding], line)
                  author_utf8  = /author: ([^;]+)/.match(line_utf8)[1]
                  author       = scm_iconv(options[:log_encoding], 'UTF-8', author_utf8)
                  file_state   = /state: ([^;]+)/.match(line)[1]
                  # TODO:
                  #    linechanges only available in CVS....
                  #    maybe a feature our SVN implementation.
                  #    I'm sure, they are useful for stats or something else
                  #                linechanges =/lines: \+(\d+) -(\d+)/.match(line)
                  #                unless linechanges.nil?
                  #                  version.line_plus  = linechanges[1]
                  #                  version.line_minus = linechanges[2]
                  #                else
                  #                  version.line_plus  = 0
                  #                  version.line_minus = 0
                  #                end
                else
                  commit_log << line unless line =~ /^\*\*\* empty log message \*\*\*/
                end
              end
            end
          end
        rescue ScmCommandAborted
          Revisions.new
        end

        def diff(path, identifier_from, identifier_to=nil)
          logger.debug "<cvs> diff path:'#{path}'" +
              ",identifier_from #{identifier_from}, identifier_to #{identifier_to}"
          cmd_args = %w|rdiff -u|
          cmd_args << "-r#{identifier_to}"
          cmd_args << "-r#{identifier_from}"
          cmd_args << path_with_proj(path)
          diff = []
          scm_cmd(*cmd_args) do |io|
            io.each_line do |line|
              diff << line
            end
          end
          diff
        rescue ScmCommandAborted
          nil
        end

        def cat(path, identifier=nil)
          identifier = (identifier) ? identifier : "HEAD"
          logger.debug "<cvs> cat path:'#{path}',identifier #{identifier}"
          cmd_args = %w|-q co|
          cmd_args << "-D" << time_to_cvstime(identifier) if identifier
          cmd_args << "-p" << path_with_proj(path)
          cat = nil
          scm_cmd(*cmd_args) do |io|
            io.binmode
            cat = io.read
          end
          cat
        rescue ScmCommandAborted
          nil
        end

        def annotate(path, identifier=nil)
          identifier = (identifier) ? identifier : "HEAD"
          logger.debug "<cvs> annotate path:'#{path}',identifier #{identifier}"
          cmd_args = %w|rannotate|
          cmd_args << "-D" << time_to_cvstime(identifier) if identifier
          cmd_args << path_with_proj(path)
          blame = Annotate.new
          scm_cmd(*cmd_args) do |io|
            io.each_line do |line|
              next unless line =~ %r{^([\d\.]+)\s+\(([^\)]+)\s+[^\)]+\):\s(.*)$}
              blame.add_line(
                  $3.rstrip,
                  Revision.new(
                    :revision   => $1,
                    :identifier => nil,
                    :author     => $2.strip
                    ))
            end
          end
          blame
        rescue ScmCommandAborted
          Annotate.new
        end

        private

        # Returns the root url without the connexion string
        # :pserver:anonymous@foo.bar:/path => /path
        # :ext:cvsservername:/path => /path
        def root_url_path
          root_url.to_s.gsub(%r{^:.+?(?=/)}, '')
        end

        # convert a date/time into the CVS-format
        def time_to_cvstime(time)
          return nil if time.nil?
          time = Time.now if (time.kind_of?(String) && time == 'HEAD')

          unless time.kind_of? Time
            time = Time.parse(time)
          end
          return time_to_cvstime_rlog(time)
        end

        def time_to_cvstime_rlog(time)
          return nil if time.nil?
          t1 = time.clone.localtime
          return t1.strftime("%Y-%m-%d %H:%M:%S")
        end

        def normalize_cvs_path(path)
          normalize_path(path.gsub(/Attic\//,''))
        end

        def normalize_path(path)
          path.sub(/^(\/)*(.*)/,'\2').sub(/(.*)(,v)+/,'\1')
        end

        def path_with_proj(path)
          "#{url}#{with_leading_slash(path)}"
        end
        private :path_with_proj

        class Revision < Redmine::Scm::Adapters::Revision
          # Returns the readable identifier
          def format_identifier
            revision.to_s
          end
        end

        def scm_cmd(*args, &block)
          full_args = ['-d', root_url]
          full_args += args
          full_args_locale = []
          full_args.map do |e|
            full_args_locale << scm_iconv(@path_encoding, 'UTF-8', e)
          end
          ret = shellout(
                   self.class.sq_bin + ' ' + full_args_locale.map { |e| shell_quote e.to_s }.join(' '),
                   &block
                   )
          if $? && $?.exitstatus != 0
            raise ScmCommandAborted, "cvs exited with non-zero status: #{$?.exitstatus}"
          end
          ret
        end
        private :scm_cmd
      end

      class CvsRevisionHelper
        attr_accessor :complete_rev, :revision, :base, :branchid

        def initialize(complete_rev)
          @complete_rev = complete_rev
          parseRevision()
        end

        def branchPoint
          return @base
        end

        def branchVersion
          if isBranchRevision
            return @base+"."+@branchid
          end
          return @base
        end

        def isBranchRevision
          !@branchid.nil?
        end

        def prevRev
          unless @revision == 0
            return buildRevision( @revision - 1 )
          end
          return buildRevision( @revision )
        end

        def is_in_branch_with_symbol(branch_symbol)
          bpieces = branch_symbol.split(".")
          branch_start = "#{bpieces[0..-3].join(".")}.#{bpieces[-1]}"
          return ( branchVersion == branch_start )
        end

        private
        def buildRevision(rev)
          if rev == 0
            if @branchid.nil?
              @base + ".0"
            else
              @base
            end
          elsif @branchid.nil?
            @base + "." + rev.to_s
          else
            @base + "." + @branchid + "." + rev.to_s
          end
        end

        # Interpretiert die cvs revisionsnummern wie z.b. 1.14 oder 1.3.0.15
        def parseRevision()
          pieces = @complete_rev.split(".")
          @revision = pieces.last.to_i
          baseSize = 1
          baseSize += (pieces.size / 2)
          @base = pieces[0..-baseSize].join(".")
          if baseSize > 2
            @branchid = pieces[-2]
          end
        end
      end
    end
  end
end
