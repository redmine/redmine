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

module Redmine
  # Wiki toolbar rendered by app/views/wiki_toolbar and handled by the
  # wiki-toolbar Stimulus controller.
  #
  # A text formatter displays the toolbar by defining WIKI_TOOLBAR_BUTTONS, the
  # groups of buttons, in its helper module. What each button inserts in the
  # text is defined in app/javascript/wiki_formatting/<format>.js.
  module WikiToolbar
    LABELS = {
      'strong' => :label_wiki_toolbar_strong,
      'em' => :label_wiki_toolbar_italic,
      'ins' => :label_wiki_toolbar_underline,
      'del' => :label_wiki_toolbar_deleted,
      'code' => :label_wiki_toolbar_code,
      'h1' => :label_wiki_toolbar_heading_1,
      'h2' => :label_wiki_toolbar_heading_2,
      'h3' => :label_wiki_toolbar_heading_3,
      'ul' => :label_wiki_toolbar_unordered_list,
      'ol' => :label_wiki_toolbar_ordered_list,
      'tl' => :label_wiki_toolbar_task_list,
      'bq' => :label_wiki_toolbar_quote,
      'unbq' => :label_wiki_toolbar_unquote,
      'table' => :label_wiki_toolbar_table,
      'pre' => :label_wiki_toolbar_preformatted_text,
      'precode' => :label_wiki_toolbar_preformatted_code,
      'link' => :label_wiki_toolbar_wiki_link,
      'img' => :label_wiki_toolbar_image,
      'help' => :label_wiki_toolbar_help
    }.freeze

    SHORTCUTS = {'strong' => 'b', 'em' => 'i', 'ins' => 'u'}.freeze
    MENUS = %w[table precode].freeze
    TABLE_MENU_ROWS = 5
    TABLE_MENU_COLS = 10

    # Returns the groups of buttons of the given text formatter, or nil if it
    # does not use the toolbar
    def self.buttons(format)
      helper = Redmine::WikiFormatting.helper_for(format)
      helper::WIKI_TOOLBAR_BUTTONS if helper.const_defined?(:WIKI_TOOLBAR_BUTTONS, false)
    end

    # Helper methods of the text formatters that use the toolbar
    module Helper
      # Renders the toolbar for an existing textarea, which is moved into the
      # toolbar in the browser.
      #
      # Deprecated: use LabelledFormBuilder#wiki_textarea or
      # WikiToolbarHelper#wiki_textarea_tag to render the textarea with its
      # toolbar.
      def wikitoolbar_for(field_id, preview_url = preview_text_path)
        Rails.application.deprecators[:redmine].warn(
          'wikitoolbar_for is deprecated and will be removed in Redmine 8.0. ' \
          'Please use LabelledFormBuilder#wiki_textarea or wiki_textarea_tag instead.'
        )
        heads_for_wiki_formatter
        render(partial: 'wiki_toolbar/toolbar',
               locals: {field_id: field_id, field: nil, preview_url: preview_url, adopt_field: true})
      end

      def heads_for_wiki_formatter
        return if @heads_for_wiki_formatter_included

        content_for :header_tags do
          javascript_tag("var wikiImageMimeTypes = #{Redmine::MimeType.by_type('image').to_json};")
        end
        @heads_for_wiki_formatter_included = true
      end
    end
  end
end
