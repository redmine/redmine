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

require 'cgi'
require 'redmine/scm/adapters'

module Redmine
  module Scm
    module Adapters
      # @private
      class AbstractAdapter
        include Redmine::Utils::Shell

        # raised if scm command exited with error, e.g. unknown revision.
        class ScmCommandAborted < ::Redmine::Scm::Adapters::CommandFailed; end

        class << self
          def client_command
            ""
          end

          def shell_quote(str)
            Redmine::Utils::Shell.shell_quote str
          end

          def shell_quote_command
            Redmine::Utils::Shell.shell_quote_command client_command
          end

          # Returns the version of the scm client
          # Eg: [1, 5, 0] or [] if unknown
          def client_version
            []
          end

          # Returns the version string of the scm client
          # Eg: '1.5.0' or 'Unknown version' if unknown
          def client_version_string
            v = client_version || 'Unknown version'
            v.is_a?(Array) ? v.join('.') : v.to_s
          end

          # Returns true if the current client version is above
          # or equals the given one
          # If option is :unknown is set to true, it will return
          # true if the client version is unknown
          def client_version_above?(v, options={})
            ((client_version <=> v) >= 0) || (client_version.empty? && options[:unknown])
          end

          def client_available
            true
          end
        end

        def initialize(url, root_url=nil, login=nil, password=nil,
                       path_encoding=nil)
          @url = url
          @login = login if login && !login.empty?
          @password = (password || "") if @login
          @root_url = root_url.blank? ? retrieve_root_url : root_url
        end

        def adapter_name
          'Abstract'
        end

        def supports_cat?
          true
        end

        def supports_annotate?
          respond_to?(:annotate)
        end

        def root_url
          @root_url
        end

        def url
          @url
        end

        def path_encoding
          nil
        end

        # get info about the svn repository
        def info
          return nil
        end

        # Returns the entry identified by path and revision identifier
        # or nil if entry doesn't exist in the repository
        def entry(path=nil, identifier=nil)
          parts = path.to_s.split(%r{[\/\\]}).select {|n| !n.blank?}
          search_path = parts[0..-2].join('/')
          search_name = parts[-1]
          if search_path.blank? && search_name.blank?
            # Root entry
            Entry.new(:path => '', :kind => 'dir')
          else
            # Search for the entry in the parent directory
            es = entries(search_path, identifier)
            es ? es.detect {|e| e.name == search_name} : nil
          end
        end

        # Returns an Entries collection
        # or nil if the given path doesn't exist in the repository
        def entries(path=nil, identifier=nil, options={})
          return nil
        end

        def branches
          return nil
        end

        def tags
          return nil
        end

        def default_branch
          return nil
        end

        def properties(path, identifier=nil)
          return nil
        end

        def revisions(path=nil, identifier_from=nil, identifier_to=nil, options={})
          return nil
        end

        def diff(path, identifier_from, identifier_to=nil)
          return nil
        end

        def cat(path, identifier=nil)
          return nil
        end

        def with_leading_slash(path)
          path ||= ''
          (path[0, 1]!="/") ? "/#{path}" : path
        end

        def with_trailling_slash(path)
          path ||= ''
          (path[-1, 1] == "/") ? path : "#{path}/"
        end

        def without_leading_slash(path)
          path ||= ''
          path.gsub(%r{^/+}, '')
        end

        def without_trailling_slash(path)
          path ||= ''
          (path[-1, 1] == "/") ? path[0..-2] : path
        end

        def valid_name?(name)
          return true if name.nil?
          return true if name.is_a?(Integer) && name > 0
          return true if name.is_a?(String) && name =~ /\A[0-9]*\z/

          false
        end

        private

        def retrieve_root_url
          info = self.info
          info ? info.root_url : nil
        end

        def target(path, sq=true)
          path ||= ''
          base = /^\//.match?(path) ? root_url : url
          str = "#{base}/#{path}".gsub(/[?<>\*]/, '')
          if sq
            str = shell_quote(str)
          end
          str
        end

        def logger
          self.class.logger
        end

        def shellout(cmd, options = {}, &block)
          self.class.shellout(cmd, options, &block)
        end

        # Path to the file where scm stderr output is logged
        # Returns nil if the log file is not writable
        def self.stderr_log_file
          if @stderr_log_file.nil?
            writable = false
            path = Redmine::Configuration['scm_stderr_log_file'].presence
            path ||= Rails.root.join("log/#{Rails.env}.scm.stderr.log").to_s
            if File.exist?(path)
              if File.file?(path) && File.writable?(path)
                writable = true
              else
                logger.warn("SCM log file (#{path}) is not writable")
              end
            else
              begin
                File.open(path, "w") {}
                writable = true
              rescue => e
                logger.warn("SCM log file (#{path}) cannot be created: #{e.message}")
              end
            end
            @stderr_log_file = writable ? path : false
          end
          @stderr_log_file || nil
        end
        private_class_method :stderr_log_file

        # Singleton class method is public
        class << self
          def logger
            Rails.logger
          end

          def shellout(cmd, options = {}, &block)
            if logger && logger.debug?
              logger.debug "Shelling out: #{strip_credential(cmd)}"
              # Capture stderr in a log file
              if stderr_log_file
                cmd = "#{cmd} 2>>#{shell_quote(stderr_log_file)}"
              end
            end
            begin
              mode = "r+"
              IO.popen(cmd, mode) do |io|
                io.set_encoding("ASCII-8BIT") if io.respond_to?(:set_encoding)
                io.close_write unless options[:write_stdin]
                yield(io) if block_given?
              end
            rescue => e
              msg = strip_credential(e.message)
              # The command failed, log it and re-raise
              logmsg = "SCM command failed, "
              logmsg += "make sure that your SCM command (e.g. svn) is "
              logmsg += "in PATH (#{ENV['PATH']})\n"
              logmsg += "You can configure your scm commands in config/configuration.yml.\n"
              logmsg += "#{strip_credential(cmd)}\n"
              logmsg += "with: #{msg}"
              logger.error(logmsg)
              raise CommandFailed.new(msg)
            end
          end
        end

        # Hides username/password in a given command
        def self.strip_credential(cmd)
          q = (Redmine::Platform.mswin? ? '"' : "'")
          cmd.to_s.gsub(/(\-\-(password|username))\s+(#{q}[^#{q}]+#{q}|[^#{q}]\S+)/, '\\1 xxxx')
        end
        private_class_method :strip_credential

        def strip_credential(cmd)
          self.class.strip_credential(cmd)
        end

        def scm_iconv(to, from, str)
          return if str.nil?
          return str if to == from && str.encoding.to_s == from

          str = str.dup
          str.force_encoding(from)
          begin
            str.encode(to)
          rescue => err
            logger.error("failed to convert from #{from} to #{to}. #{err}")
            nil
          end
        end

        def parse_xml(xml)
          if RUBY_PLATFORM == 'java'
            xml = xml.sub(%r{<\?xml[^>]*\?>}, '')
          end
          ActiveSupport::XmlMini.parse(xml)
        end
      end

      class Entries < Array
        def sort_by_name
          dup.sort! do |x, y|
            if x.kind == y.kind
              x.name.to_s <=> y.name.to_s
            else
              x.kind <=> y.kind
            end
          end
        end

        def revisions
          revisions ||= Revisions.new(collect{|entry| entry.lastrev}.compact)
        end
      end

      class Info
        attr_accessor :root_url, :lastrev
        def initialize(attributes={})
          self.root_url = attributes[:root_url] if attributes[:root_url]
          self.lastrev = attributes[:lastrev]
        end
      end

      class Entry
        attr_accessor :name, :path, :kind, :size, :lastrev, :changeset

        def initialize(attributes={})
          self.name = attributes[:name] if attributes[:name]
          self.path = attributes[:path] if attributes[:path]
          self.kind = attributes[:kind] if attributes[:kind]
          self.size = attributes[:size].to_i if attributes[:size]
          self.lastrev = attributes[:lastrev]
        end

        def is_file?
          self.kind == 'file'
        end

        def is_dir?
          self.kind == 'dir'
        end

        def is_text?
          Redmine::MimeType.is_type?('text', name)
        end

        def author
          if changeset
            changeset.author.to_s
          elsif lastrev
            Redmine::CodesetUtil.replace_invalid_utf8(lastrev.author.to_s.split('<').first)
          end
        end
      end

      class Revisions < Array
        def latest
          sort do |x, y|
            unless x.time.nil? or y.time.nil?
              x.time <=> y.time
            else
              0
            end
          end.last
        end
      end

      class Revision
        attr_accessor :scmid, :name, :author, :time, :message,
                      :paths, :revision, :branch, :identifier,
                      :parents

        def initialize(attributes={})
          self.identifier = attributes[:identifier]
          self.scmid      = attributes[:scmid]
          self.name       = attributes[:name] || self.identifier
          self.author     = attributes[:author]
          self.time       = attributes[:time]
          self.message    = attributes[:message] || ""
          self.paths      = attributes[:paths]
          self.revision   = attributes[:revision]
          self.branch     = attributes[:branch]
          self.parents    = attributes[:parents]
        end

        # Returns the readable identifier.
        def format_identifier
          self.identifier.to_s
        end

        def ==(other)
          if other.nil?
            false
          elsif scmid.present?
            scmid == other.scmid
          elsif identifier.present?
            identifier == other.identifier
          elsif revision.present?
            revision == other.revision
          end
        end
      end

      class Annotate
        attr_reader :lines, :revisions

        def initialize
          @lines = []
          @revisions = []
        end

        def add_line(line, revision)
          @lines << line
          @revisions << revision
        end

        def content
          content = lines.join("\n")
        end

        def empty?
          lines.empty?
        end
      end

      class Branch < String
        attr_accessor :revision, :scmid
      end

      module ScmData
        def self.binary?(data)
          unless data.empty?
            data.count("^ -~", "^\r\n").fdiv(data.size) > 0.3 || data.index("\x00")
          end
        end
      end
    end
  end
end
