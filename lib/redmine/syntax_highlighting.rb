# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

module Redmine
  module SyntaxHighlighting

    class << self
      attr_reader :highlighter

      def highlighter=(name)
        if name.is_a?(Module)
          @highlighter = name
        else
          @highlighter = const_get(name)
        end
      end

      def highlight_by_filename(text, filename)
        highlighter.highlight_by_filename(text, filename)
      rescue
        ERB::Util.h(text)
      end

      def highlight_by_language(text, language)
        highlighter.highlight_by_language(text, language)
      rescue
        ERB::Util.h(text)
      end

      def language_supported?(language)
        if highlighter.respond_to? :language_supported?
          highlighter.language_supported? language
        else
          true
        end
      rescue
        false
      end
    end

    module CodeRay
      require 'coderay'

      def self.retrieve_supported_languages
        ::CodeRay::Scanners.list +
        # Add CodeRay scanner aliases
        ::CodeRay::Scanners.plugin_hash.keys.map(&:to_sym) -
        # Remove internal CodeRay scanners
        %w(debug default raydebug scanner).map(&:to_sym)
      end
      private_class_method :retrieve_supported_languages

      SUPPORTED_LANGUAGES = retrieve_supported_languages

      class << self
        # Highlights +text+ as the content of +filename+
        # Should not return line numbers nor outer pre tag
        def highlight_by_filename(text, filename)
          language = ::CodeRay::FileType[filename]
          language ? ::CodeRay.scan(text, language).html(:break_lines => true) : ERB::Util.h(text)
        end

        # Highlights +text+ using +language+ syntax
        # Should not return outer pre tag
        def highlight_by_language(text, language)
          ::CodeRay.scan(text, language).html(:wrap => :span)
        end

        def language_supported?(language)
          SUPPORTED_LANGUAGES.include?(language.to_s.downcase.to_sym)
        rescue
          false
        end
      end
    end
  end

  SyntaxHighlighting.highlighter = 'CodeRay'
end
