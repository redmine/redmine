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

require 'erb'
require 'cgi'

# A simple formatter for SimpleCov
module Redmine
  module Coverage
    class HtmlFormatter
      def format(result)
        File.open(File.join(output_path, "index.html"), "w") do |file|
          file.puts template('index').result(binding)
        end
        result.source_files.each do |source_file|
          File.open(File.join(output_path, source_file_result(source_file)), "w") do |file|
            file.puts template('source').result(binding).force_encoding('utf-8')
          end
        end
        puts output_message(result)
      end

      def output_message(result)
        "Coverage report generated for #{result.command_name} to #{output_path}. #{result.covered_lines} / #{result.total_lines} LOC (#{result.covered_percent.round(2)}%) covered."
      end

      private

      def now
        @now = Time.now.utc
      end

      def output_path
        SimpleCov.coverage_path
      end

      def shortened_filename(source_file)
        source_file.filename.gsub(SimpleCov.root, '.').delete_prefix('./')
      end

      def link_to_source_file(source_file)
        %(<a href="#{source_file_result source_file}">#{shortened_filename source_file}</a>)
      end

      def source_file_result(source_file)
        shortened_filename(source_file).gsub('/', '__')+'.html'
      end

      def revision_link
        if revision = Redmine::VERSION.revision
          %(<a href="http://www.redmine.org/projects/redmine/repository/revisions/#{revision}">r#{revision}</a>)
        end
      end

      # Returns the an erb instance for the template of given name
      def template(name)
        ERB.new(File.read(File.join(File.dirname(__FILE__), 'views', "#{name}.erb")))
      end
    end
  end
end
