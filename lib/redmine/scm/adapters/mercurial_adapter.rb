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

require 'redmine/scm/adapters/abstract_adapter'
require 'cgi'

module Redmine
  module Scm
    module Adapters
      class MercurialAdapter < AbstractAdapter
        # Mercurial executable name
        HG_BIN = Redmine::Configuration['scm_mercurial_command'] || "hg"
        HELPERS_DIR = File.dirname(__FILE__) + "/mercurial"
        HG_HELPER_EXT = "#{HELPERS_DIR}/redminehelper.py"
        TEMPLATE_NAME = "hg-template"
        TEMPLATE_EXTENSION = "tmpl"

        # raised if hg command exited with error, e.g. unknown revision.
        class HgCommandAborted < CommandFailed; end
        # raised if bad command argument detected before executing hg.
        class HgCommandArgumentError < CommandFailed; end

        class << self
          def client_command
            @@bin    ||= HG_BIN
          end

          def sq_bin
            @@sq_bin ||= shell_quote_command
          end

          def client_version
            @@client_version ||= (hgversion || [])
          end

          def client_available
            client_version_above?([1, 2])
          end

          def hgversion
            # The hg version is expressed either as a
            # release number (eg 0.9.5 or 1.0) or as a revision
            # id composed of 12 hexa characters.
            theversion = hgversion_from_command_line.b
            if m = theversion.match(%r{\A(.*?)((\d+\.)+\d+)})
              m[2].scan(%r{\d+}).collect(&:to_i)
            end
          end

          def hgversion_from_command_line
            shellout("#{sq_bin} --version") {|io| io.read}.to_s
          end

          def template_path
            @@template_path ||= template_path_for(client_version)
          end

          def template_path_for(version)
            "#{HELPERS_DIR}/#{TEMPLATE_NAME}-1.0.#{TEMPLATE_EXTENSION}"
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
          tip = summary['repository']['tip']
          Info.new(:root_url => CGI.unescape(summary['repository']['root']),
                   :lastrev => Revision.new(:revision => tip['revision'],
                                            :scmid => tip['node']))
        # rescue HgCommandAborted
        rescue => e
          logger.error "hg: error during getting info: #{e.message}"
          nil
        end

        def tags
          as_ary(summary['repository']['tag']).map {|e| CGI.unescape(e['name'])}
        end

        # Returns map of {'tag' => 'nodeid', ...}
        def tagmap
          map = {}
          as_ary(summary['repository']['tag']).each do |e|
            map[CGI.unescape(e['name'])] = e['node']
          end
          map
        end

        def branches
          brs = []
          as_ary(summary['repository']['branch']).each do |e|
            br = Branch.new(CGI.unescape(e['name']))
            br.revision =  e['revision']
            br.scmid    =  e['node']
            brs << br
          end
          brs
        end

        # Returns map of {'branch' => 'nodeid', ...}
        def branchmap
          map = {}
          branches.each do |b|
            map[b.to_s] = b.scmid
          end
          map
        end

        def summary
          return @summary if @summary

          hg 'rhsummary' do |io|
            output = io.read.force_encoding('UTF-8')
            begin
              @summary = parse_xml(output)['rhsummary']
            rescue
              # do nothing
            end
          end
        end
        private :summary

        def entries(path=nil, identifier=nil, options={})
          p1 = scm_iconv(@path_encoding, 'UTF-8', path)
          manifest = hg('rhmanifest', "-r#{CGI.escape(hgrev(identifier))}",
                        '--', CGI.escape(without_leading_slash(p1.to_s))) do |io|
            output = io.read.force_encoding('UTF-8')
            begin
              parse_xml(output)['rhmanifest']['repository']['manifest']
            rescue
              # do nothing
            end
          end
          path_prefix = path.blank? ? '' : with_trailling_slash(path)

          entries = Entries.new
          as_ary(manifest['dir']).each do |e|
            n = scm_iconv('UTF-8', @path_encoding, CGI.unescape(e['name']))
            p = "#{path_prefix}#{n}"
            entries << Entry.new(:name => n, :path => p, :kind => 'dir')
          end

          as_ary(manifest['file']).each do |e|
            n = scm_iconv('UTF-8', @path_encoding, CGI.unescape(e['name']))
            p = "#{path_prefix}#{n}"
            lr = Revision.new(:revision => e['revision'], :scmid => e['node'],
                              :identifier => e['node'],
                              :time => Time.at(e['time'].to_i))
            entries << Entry.new(:name => n, :path => p, :kind => 'file',
                                 :size => e['size'].to_i, :lastrev => lr)
          end

          entries
        rescue HgCommandAborted
          nil  # means not found
        end

        def revisions(path=nil, identifier_from=nil, identifier_to=nil, options={})
          revs = Revisions.new
          each_revision(path, identifier_from, identifier_to, options) {|e| revs << e}
          revs
        end

        # Iterates the revisions by using a template file that
        # makes Mercurial produce a xml output.
        def each_revision(path=nil, identifier_from=nil, identifier_to=nil, options={})
          hg_args = ['log', '--debug', '-C', "--style=#{self.class.template_path}"]
          hg_args << "-r#{hgrev(identifier_from)}:#{hgrev(identifier_to)}"
          hg_args << "--limit=#{options[:limit]}" if options[:limit]
          hg_args << '--' << hgtarget(path) unless path.blank?
          log = hg(*hg_args) do |io|
            output = io.read.force_encoding('UTF-8')
            begin
              # Mercurial < 1.5 does not support footer template for '</log>'
              parse_xml("#{output}</log>")['log']
            rescue
              # do nothing
            end
          end
          as_ary(log['logentry']).each do |le|
            cpalist = as_ary(le['paths']['path-copied']).map do |e|
              [e['__content__'], e['copyfrom-path']].map do |s|
                scm_iconv('UTF-8', @path_encoding, CGI.unescape(s))
              end
            end
            cpmap = Hash[*cpalist.flatten]
            paths = as_ary(le['paths']['path']).map do |e|
              p = scm_iconv('UTF-8', @path_encoding, CGI.unescape(e['__content__']))
              {:action        => e['action'],
               :path          => with_leading_slash(p),
               :from_path     => (cpmap.member?(p) ? with_leading_slash(cpmap[p]) : nil),
               :from_revision => (cpmap.member?(p) ? le['node'] : nil)}
            end
            paths.sort_by!{|e| e[:path]}
            parents_ary = []
            as_ary(le['parents']['parent']).map do |par|
              parents_ary << par['__content__'] if par['__content__'] != "0000000000000000000000000000000000000000"
            end
            yield Revision.new(:revision => le['revision'],
                               :scmid    => le['node'],
                               :author   =>
                                 CGI.unescape(
                                   begin
                                     le['author']['__content__']
                                   rescue
                                     ''
                                   end
                                 ),
                               :time     => Time.parse(le['date']['__content__']),
                               :message  => CGI.unescape(le['msg']['__content__'] || ''),
                               :paths    => paths,
                               :parents  => parents_ary)
          end
          self
        end

        # Returns list of nodes in the specified branch
        def nodes_in_branch(branch, options={})
          hg_args = ['rhlog', '--template={node}\n', "--rhbranch=#{CGI.escape(branch)}"]
          hg_args << "--from=#{CGI.escape(branch)}"
          hg_args << '--to=0'
          hg_args << "--limit=#{options[:limit]}" if options[:limit]
          hg(*hg_args) {|io| io.readlines.map {|e| e.chomp}}
        end

        def diff(path, identifier_from, identifier_to=nil)
          hg_args = %w|rhdiff|
          if identifier_to
            hg_args << "-r#{hgrev(identifier_to)}" << "-r#{hgrev(identifier_from)}"
          else
            hg_args << "-c#{hgrev(identifier_from)}"
          end
          unless path.blank?
            p = scm_iconv(@path_encoding, 'UTF-8', path)
            hg_args << '--' << CGI.escape(hgtarget(p))
          end
          diff = []
          hg(*hg_args) do |io|
            io.each_line do |line|
              diff << line
            end
          end
          diff
        rescue HgCommandAborted
          nil  # means not found
        end

        def cat(path, identifier=nil)
          p = CGI.escape(scm_iconv(@path_encoding, 'UTF-8', path))
          hg 'rhcat', "-r#{CGI.escape(hgrev(identifier))}", '--', hgtarget(p) do |io|
            io.binmode
            io.read
          end
        rescue HgCommandAborted
          nil  # means not found
        end

        def annotate(path, identifier=nil)
          p = CGI.escape(scm_iconv(@path_encoding, 'UTF-8', path))
          blame = Annotate.new
          hg 'rhannotate', '-ncu', "-r#{CGI.escape(hgrev(identifier))}", '--', hgtarget(p) do |io|
            io.each_line do |line|
              next unless line.b =~ %r{^([^:]+)\s(\d+)\s([0-9a-f]+):\s(.*)$}

              r = Revision.new(:author => $1.strip, :revision => $2, :scmid => $3,
                               :identifier => $3)
              blame.add_line($4.rstrip, r)
            end
          end
          blame
        rescue HgCommandAborted
          # means not found or cannot be annotated
          Annotate.new
        end

        def valid_name?(name)
          return false unless name.nil? || name.is_a?(String)

          # Mercurials names don't need to be checked further as its CLI
          # interface is restrictive enough to reject any invalid names on its
          # own.
          true
        end

        class Revision < Redmine::Scm::Adapters::Revision
          # Returns the readable identifier
          def format_identifier
            "#{revision}:#{scmid}"
          end
        end

        # command options which may be processed earlier, by faulty parser in hg
        HG_EARLY_BOOL_ARG = /^--(debugger|profile|traceback)$/
        HG_EARLY_LIST_ARG = /^(--(config|cwd|repo(sitory)?)\b|-R)/
        private_constant :HG_EARLY_BOOL_ARG, :HG_EARLY_LIST_ARG

        # Runs 'hg' command with the given args
        def hg(*args, &block)
          # as of hg 4.4.1, early parsing of bool options is not terminated at '--'
          if args.any? {|s| HG_EARLY_BOOL_ARG.match?(s)}
            raise HgCommandArgumentError, "malicious command argument detected"
          end
          if args.take_while {|s| s != '--'}.any? {|s| HG_EARLY_LIST_ARG.match?(s)}
            raise HgCommandArgumentError, "malicious command argument detected"
          end

          repo_path = root_url || url
          full_args = ["-R#{repo_path}", '--encoding=utf-8']
          # don't use "--config=<value>" form for compatibility with ancient Mercurial
          full_args << '--config' << "extensions.redminehelper=#{HG_HELPER_EXT}"
          full_args << '--config' << 'diff.git=false'
          full_args += args
          ret =
            shellout(
              self.class.sq_bin + ' ' + full_args.map {|e| shell_quote e.to_s}.join(' '),
              &block
            )
          if $? && $?.exitstatus != 0
            raise HgCommandAborted, "hg exited with non-zero status: #{$?.exitstatus}"
          end

          ret
        end
        private :hg

        # Returns correct revision identifier
        def hgrev(identifier, sq=false)
          rev = identifier.blank? ? 'tip' : identifier.to_s
          rev = shell_quote(rev) if sq
          rev
        end
        private :hgrev

        def hgtarget(path)
          path ||= ''
          root_url + '/' + without_leading_slash(path)
        end
        private :hgtarget

        def as_ary(o)
          return [] unless o

          o.is_a?(Array) ? o : Array[o]
        end
        private :as_ary
      end
    end
  end
end
