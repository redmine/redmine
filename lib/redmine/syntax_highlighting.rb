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

      def filename_supported?(filename)
        if highlighter.respond_to? :filename_supported?
          highlighter.filename_supported? filename
        else
          false
        end
      end
    end

    module Rouge
      require 'rouge'

      # Customized formatter based on Rouge::Formatters::HTMLLinewise
      # Syntax highlighting is completed within each line.
      class CustomHTMLLinewise < ::Rouge::Formatter
        def initialize(formatter)
          @formatter = formatter
        end

        def stream(tokens, &b)
          token_lines(tokens) do |line|
            line.each do |tok, val|
              yield @formatter.span(tok, val)
            end
            yield "\n"
          end
        end
      end

      class << self
        # Highlights +text+ as the content of +filename+
        # Should not return line numbers nor outer pre tag
        def highlight_by_filename(text, filename)
          # TODO: Delete the following workaround for #30434 and
          # test_syntax_highlight_should_normalize_line_endings in
          # application_helper_test.rb when Rouge is improved to
          # handle CRLF properly.
          # See also: https://github.com/jneen/rouge/pull/1078
          text = text.gsub(/\r\n?/, "\n")

          lexer =::Rouge::Lexer.guess(:source => text, :filename => filename)
          formatter = ::Rouge::Formatters::HTML.new
          ::Rouge.highlight(text, lexer, CustomHTMLLinewise.new(formatter))
        end

        # Highlights +text+ using +language+ syntax
        # Should not return outer pre tag
        def highlight_by_language(text, language)
          lexer =
            find_lexer(language.to_s.downcase) || ::Rouge::Lexers::PlainText
          ::Rouge.highlight(text, lexer, ::Rouge::Formatters::HTML)
        end

        def language_supported?(language)
          find_lexer(language.to_s.downcase) ? true : false
        end

        def filename_supported?(filename)
          !::Rouge::Lexer.guesses(:filename => filename).empty?
        end

        private

        # Alias names used by CodeRay and not supported by Rouge
        LANG_ALIASES = {
          'delphi' => 'pascal',
          'cplusplus' => 'cpp',
          'ecmascript' => 'javascript',
          'ecma_script' => 'javascript',
          'java_script' => 'javascript',
          'xhtml' => 'html'
        }

        def find_lexer(language)
          ::Rouge::Lexer.find(language) ||
            ::Rouge::Lexer.find(LANG_ALIASES[language])
        end
      end
    end
  end

  SyntaxHighlighting.highlighter = 'Rouge'
end
