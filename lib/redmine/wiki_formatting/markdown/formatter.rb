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

module Redmine
  module WikiFormatting
    module Markdown
      class HTML < Redcarpet::Render::HTML
        include ActionView::Helpers::TagHelper
        include Redmine::Helpers::URL

        def link(link, title, content)
          return nil unless uri_with_safe_scheme?(link)

          css = nil
          unless link && link.starts_with?('/')
            css = 'external'
          end
          content_tag('a', content.to_s.html_safe, :href => link, :title => title, :class => css)
        end

        def block_code(code, language)
          if language.present? && Redmine::SyntaxHighlighting.language_supported?(language)
            html = Redmine::SyntaxHighlighting.highlight_by_language(code, language)
            classattr = " class=\"#{CGI.escapeHTML language} syntaxhl\""
          else
            html = CGI.escapeHTML(code)
          end
          # original language for extension development
          langattr = " data-language=\"#{CGI.escapeHTML language}\"" if language.present?
          "<pre><code#{classattr}#{langattr}>#{html}</code></pre>"
        end

        def image(link, title, alt_text)
          return unless uri_with_safe_scheme?(link)

          tag('img', :src => link, :alt => alt_text || "", :title => title)
        end
      end

      class Formatter
        include Redmine::WikiFormatting::LinksHelper
        include Redmine::WikiFormatting::SectionHelper
        alias :inline_restore_redmine_links :restore_redmine_links

        def initialize(text)
          @text = text
        end

        def to_html(*args)
          html = formatter.render(@text)
          html = inline_restore_redmine_links(html)
          html
        end

        private

        def formatter
          @@formatter ||= Redcarpet::Markdown.new(
            Redmine::WikiFormatting::Markdown::HTML.new(
              :filter_html => true,
              :hard_wrap => true
            ),
            :autolink => true,
            :fenced_code_blocks => true,
            :space_after_headers => true,
            :tables => true,
            :strikethrough => true,
            :superscript => true,
            :no_intra_emphasis => true,
            :footnotes => true,
            :lax_spacing => true,
            :underline => true
          )
        end
      end
    end
  end
end
