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

require 'redmine/scm/adapters/abstract_adapter'

module Redmine
  module Scm
    module Adapters
      class GitAdapter < AbstractAdapter

        # Git executable name
        GIT_BIN = Redmine::Configuration['scm_git_command'] || "git"

        class GitBranch < Branch
          attr_accessor :is_default
        end

        class << self
          def client_command
            @@bin    ||= GIT_BIN
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
            scm_version = scm_version_from_command_line.dup.force_encoding('ASCII-8BIT')
            if m = scm_version.match(%r{\A(.*?)((\d+\.)+\d+)})
              m[2].scan(%r{\d+}).collect(&:to_i)
            end
          end

          def scm_version_from_command_line
            shellout("#{sq_bin} --version --no-color") { |io| io.read }.to_s
          end
        end

        def initialize(url, root_url=nil, login=nil, password=nil, path_encoding=nil)
          super
          @path_encoding = path_encoding.blank? ? 'UTF-8' : path_encoding
        end

        def path_encoding
          @path_encoding
        end

        def info
          begin
            Info.new(:root_url => url, :lastrev => lastrev('',nil))
          rescue
            nil
          end
        end

        def branches
          return @branches if @branches
          @branches = []
          cmd_args = %w|branch --no-color --verbose --no-abbrev|
          git_cmd(cmd_args) do |io|
            io.each_line do |line|
              branch_rev = line.match('\s*(\*?)\s*(.*?)\s*([0-9a-f]{40}).*$')
              bran = GitBranch.new(branch_rev[2])
              bran.revision =  branch_rev[3]
              bran.scmid    =  branch_rev[3]
              bran.is_default = ( branch_rev[1] == '*' )
              @branches << bran
            end
          end
          @branches.sort!
        rescue ScmCommandAborted
          nil
        end

        def tags
          return @tags if @tags
          @tags = []
          cmd_args = %w|tag|
          git_cmd(cmd_args) do |io|
            @tags = io.readlines.sort!.map{|t| t.strip}
          end
          @tags
        rescue ScmCommandAborted
          nil
        end

        def default_branch
          bras = self.branches
          return nil if bras.nil?
          default_bras = bras.select{|x| x.is_default == true}
          return default_bras.first.to_s if ! default_bras.empty?
          master_bras = bras.select{|x| x.to_s == 'master'}
          master_bras.empty? ? bras.first.to_s : 'master'
        end

        def entry(path=nil, identifier=nil)
          parts = path.to_s.split(%r{[\/\\]}).select {|n| !n.blank?}
          search_path = parts[0..-2].join('/')
          search_name = parts[-1]
          if search_path.blank? && search_name.blank?
            # Root entry
            Entry.new(:path => '', :kind => 'dir')
          else
            # Search for the entry in the parent directory
            es = entries(search_path, identifier,
                         options = {:report_last_commit => false})
            es ? es.detect {|e| e.name == search_name} : nil
          end
        end

        def entries(path=nil, identifier=nil, options={})
          path ||= ''
          p = scm_iconv(@path_encoding, 'UTF-8', path)
          entries = Entries.new
          cmd_args = %w|ls-tree -l|
          cmd_args << "HEAD:#{p}"          if identifier.nil?
          cmd_args << "#{identifier}:#{p}" if identifier
          git_cmd(cmd_args) do |io|
            io.each_line do |line|
              e = line.chomp.to_s
              if e =~ /^\d+\s+(\w+)\s+([0-9a-f]{40})\s+([0-9-]+)\t(.+)$/
                type = $1
                sha  = $2
                size = $3
                name = $4.force_encoding(@path_encoding)
                full_path = p.empty? ? name : "#{p}/#{name}"
                n      = scm_iconv('UTF-8', @path_encoding, name)
                full_p = scm_iconv('UTF-8', @path_encoding, full_path)
                entries << Entry.new({:name => n,
                 :path => full_p,
                 :kind => (type == "tree") ? 'dir' : 'file',
                 :size => (type == "tree") ? nil : size,
                 :lastrev => options[:report_last_commit] ?
                                 lastrev(full_path, identifier) : Revision.new
                }) unless entries.detect{|entry| entry.name == name}
              end
            end
          end
          entries.sort_by_name
        rescue ScmCommandAborted
          nil
        end

        def lastrev(path, rev)
          return nil if path.nil?
          cmd_args = %w|log --no-color --encoding=UTF-8 --date=iso --pretty=fuller --no-merges -n 1|
          cmd_args << rev if rev
          cmd_args << "--" << path unless path.empty?
          lines = []
          git_cmd(cmd_args) { |io| lines = io.readlines }
          begin
              id = lines[0].split[1]
              author = lines[1].match('Author:\s+(.*)$')[1]
              time = Time.parse(lines[4].match('CommitDate:\s+(.*)$')[1])

              Revision.new({
                :identifier => id,
                :scmid      => id,
                :author     => author,
                :time       => time,
                :message    => nil,
                :paths      => nil
                })
          rescue NoMethodError => e
              logger.error("The revision '#{path}' has a wrong format")
              return nil
          end
        rescue ScmCommandAborted
          nil
        end

        def revisions(path, identifier_from, identifier_to, options={})
          revs = Revisions.new
          cmd_args = %w|log --no-color --encoding=UTF-8 --raw --date=iso --pretty=fuller --parents --stdin|
          cmd_args << "--reverse" if options[:reverse]
          cmd_args << "-n" << "#{options[:limit].to_i}" if options[:limit]
          cmd_args << "--" << scm_iconv(@path_encoding, 'UTF-8', path) if path && !path.empty?
          revisions = []
          if identifier_from || identifier_to
            revisions << ""
            revisions[0] << "#{identifier_from}.." if identifier_from
            revisions[0] << "#{identifier_to}" if identifier_to
          else
            unless options[:includes].blank?
              revisions += options[:includes]
            end
            unless options[:excludes].blank?
              revisions += options[:excludes].map{|r| "^#{r}"}
            end
          end

          git_cmd(cmd_args, {:write_stdin => true}) do |io|
            io.binmode
            io.puts(revisions.join("\n"))
            io.close_write
            files=[]
            changeset = {}
            parsing_descr = 0  #0: not parsing desc or files, 1: parsing desc, 2: parsing files

            io.each_line do |line|
              if line =~ /^commit ([0-9a-f]{40})(( [0-9a-f]{40})*)$/
                key = "commit"
                value = $1
                parents_str = $2
                if (parsing_descr == 1 || parsing_descr == 2)
                  parsing_descr = 0
                  revision = Revision.new({
                    :identifier => changeset[:commit],
                    :scmid      => changeset[:commit],
                    :author     => changeset[:author],
                    :time       => Time.parse(changeset[:date]),
                    :message    => changeset[:description],
                    :paths      => files,
                    :parents    => changeset[:parents]
                  })
                  if block_given?
                    yield revision
                  else
                    revs << revision
                  end
                  changeset = {}
                  files = []
                end
                changeset[:commit] = $1
                unless parents_str.nil? or parents_str == ""
                  changeset[:parents] = parents_str.strip.split(' ')
                end
              elsif (parsing_descr == 0) && line =~ /^(\w+):\s*(.*)$/
                key = $1
                value = $2
                if key == "Author"
                  changeset[:author] = value
                elsif key == "CommitDate"
                  changeset[:date] = value
                end
              elsif (parsing_descr == 0) && line.chomp.to_s == ""
                parsing_descr = 1
                changeset[:description] = ""
              elsif (parsing_descr == 1 || parsing_descr == 2) \
                  && line =~ /^:\d+\s+\d+\s+[0-9a-f.]+\s+[0-9a-f.]+\s+(\w)\t(.+)$/
                parsing_descr = 2
                fileaction    = $1
                filepath      = $2
                p = scm_iconv('UTF-8', @path_encoding, filepath)
                files << {:action => fileaction, :path => p}
              elsif (parsing_descr == 1 || parsing_descr == 2) \
                  && line =~ /^:\d+\s+\d+\s+[0-9a-f.]+\s+[0-9a-f.]+\s+(\w)\d+\s+(\S+)\t(.+)$/
                parsing_descr = 2
                fileaction    = $1
                filepath      = $3
                p = scm_iconv('UTF-8', @path_encoding, filepath)
                files << {:action => fileaction, :path => p}
              elsif (parsing_descr == 1) && line.chomp.to_s == ""
                parsing_descr = 2
              elsif (parsing_descr == 1)
                changeset[:description] << line[4..-1]
              end
            end

            if changeset[:commit]
              revision = Revision.new({
                :identifier => changeset[:commit],
                :scmid      => changeset[:commit],
                :author     => changeset[:author],
                :time       => Time.parse(changeset[:date]),
                :message    => changeset[:description],
                :paths      => files,
                :parents    => changeset[:parents]
                 })
              if block_given?
                yield revision
              else
                revs << revision
              end
            end
          end
          revs
        rescue ScmCommandAborted => e
          err_msg = "git log error: #{e.message}"
          logger.error(err_msg)
          if block_given?
            raise CommandFailed, err_msg
          else
            revs
          end
        end

        def diff(path, identifier_from, identifier_to=nil)
          path ||= ''
          cmd_args = []
          if identifier_to
            cmd_args << "diff" << "--no-color" <<  identifier_to << identifier_from
          else
            cmd_args << "show" << "--no-color" << identifier_from
          end
          cmd_args << "--" <<  scm_iconv(@path_encoding, 'UTF-8', path) unless path.empty?
          diff = []
          git_cmd(cmd_args) do |io|
            io.each_line do |line|
              diff << line
            end
          end
          diff
        rescue ScmCommandAborted
          nil
        end

        def annotate(path, identifier=nil)
          identifier = 'HEAD' if identifier.blank?
          cmd_args = %w|blame --encoding=UTF-8|
          cmd_args << "-p" << identifier << "--" <<  scm_iconv(@path_encoding, 'UTF-8', path)
          blame = Annotate.new
          content = nil
          git_cmd(cmd_args) { |io| io.binmode; content = io.read }
          # git annotates binary files
          return nil if content.is_binary_data?
          identifier = ''
          # git shows commit author on the first occurrence only
          authors_by_commit = {}
          content.split("\n").each do |line|
            if line =~ /^([0-9a-f]{39,40})\s.*/
              identifier = $1
            elsif line =~ /^author (.+)/
              authors_by_commit[identifier] = $1.strip
            elsif line =~ /^\t(.*)/
              blame.add_line($1, Revision.new(
                                    :identifier => identifier,
                                    :revision   => identifier,
                                    :scmid      => identifier,
                                    :author     => authors_by_commit[identifier]
                                    ))
              identifier = ''
              author = ''
            end
          end
          blame
        rescue ScmCommandAborted
          nil
        end

        def cat(path, identifier=nil)
          if identifier.nil?
            identifier = 'HEAD'
          end
          cmd_args = %w|show --no-color|
          cmd_args << "#{identifier}:#{scm_iconv(@path_encoding, 'UTF-8', path)}"
          cat = nil
          git_cmd(cmd_args) do |io|
            io.binmode
            cat = io.read
          end
          cat
        rescue ScmCommandAborted
          nil
        end

        class Revision < Redmine::Scm::Adapters::Revision
          # Returns the readable identifier
          def format_identifier
            identifier[0,8]
          end
        end

        def git_cmd(args, options = {}, &block)
          repo_path = root_url || url
          full_args = ['--git-dir', repo_path]
          if self.class.client_version_above?([1, 7, 2])
            full_args << '-c' << 'core.quotepath=false'
            full_args << '-c' << 'log.decorate=no'
          end
          full_args += args
          ret = shellout(
                   self.class.sq_bin + ' ' + full_args.map { |e| shell_quote e.to_s }.join(' '),
                   options,
                   &block
                   )
          if $? && $?.exitstatus != 0
            raise ScmCommandAborted, "git exited with non-zero status: #{$?.exitstatus}"
          end
          ret
        end
        private :git_cmd
      end
    end
  end
end
