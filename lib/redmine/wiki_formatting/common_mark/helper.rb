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
  module WikiFormatting
    module CommonMark
      module Helper
        def wikitoolbar_for(field_id, preview_url = preview_text_path)
          heads_for_wiki_formatter
          help_file = "/help/#{current_language.to_s.downcase}/wiki_syntax_common_mark.html"
          # fall back to the english help page if there is none for the current
          # language
          unless File.readable? Rails.root.join("public", help_file)
            help_file = "/help/en/wiki_syntax_common_mark.html"
          end
          url = "#{Redmine::Utils.relative_url_root}#{help_file}"
          javascript_tag(
            "var wikiToolbar = new jsToolBar(document.getElementById('#{field_id}')); " \
            "wikiToolbar.setHelpLink('#{escape_javascript url}'); " \
            "wikiToolbar.setPreviewUrl('#{escape_javascript preview_url}'); " \
            "wikiToolbar.draw();"
          )
        end

        def initial_page_content(page)
          "# #{@page.pretty_title}"
        end

        def heads_for_wiki_formatter
          unless @heads_for_wiki_formatter_included
            toolbar_language_options = User.current && User.current.pref.toolbar_language_options
            lang =
              if toolbar_language_options.nil?
                UserPreference::DEFAULT_TOOLBAR_LANGUAGE_OPTIONS
              else
                toolbar_language_options.split(',')
              end
            content_for :header_tags do
              javascript_include_tag('jstoolbar/jstoolbar') +
              javascript_include_tag('jstoolbar/common_mark') +
              javascript_include_tag("jstoolbar/lang/jstoolbar-#{current_language.to_s.downcase}") +
              javascript_tag(
                "var wikiImageMimeTypes = #{Redmine::MimeType.by_type('image').to_json};" \
                  "var userHlLanguages = #{lang.to_json};"
              ) +
              stylesheet_link_tag('jstoolbar')
            end
            @heads_for_wiki_formatter_included = true
          end
        end
      end
    end
  end
end
