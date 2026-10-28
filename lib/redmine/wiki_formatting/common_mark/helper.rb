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
  module WikiFormatting
    module CommonMark
      module Helper
        include Redmine::WikiToolbar::Helper

        def wiki_toolbar
          @wiki_toolbar ||= WikiToolbar.new(self)
        end

        def initial_page_content(page)
          "# #{page.pretty_title}"
        end
      end

      class WikiToolbar < Redmine::WikiToolbar
        def buttons
          [
            {name: 'strong', action: 'wrap', prefix: '**', shortcut: 'b'},
            {name: 'em', action: 'wrap', prefix: '*', shortcut: 'i'},
            {name: 'ins', action: 'wrap', prefix: '<u>', suffix: '</u>', shortcut: 'u'},
            {name: 'del', action: 'wrap', prefix: '~~'},
            {name: 'code', action: 'wrap', prefix: '`'},
            SPACER,
            {name: 'h1', action: 'wrapLines', prefix: '# ', strip: '^#+\s+'},
            {name: 'h2', action: 'wrapLines', prefix: '## ', strip: '^#+\s+'},
            {name: 'h3', action: 'wrapLines', prefix: '### ', strip: '^#+\s+'},
            SPACER,
            {name: 'ul', action: 'wrapLines', pattern: '[#-]?\s*', replacement: '* '},
            {name: 'ol', action: 'wrapLines', pattern: '[*-]?\s*', replacement: '1. '},
            {name: 'tl', action: 'wrapLines', pattern: '[*-]?\s*', replacement: '* [ ] '},
            SPACER,
            {name: 'bq', action: 'wrapLines', pattern: '( *)([^\n]*)', replacement: '> $2$3'},
            {name: 'unbq', action: 'wrapLines', pattern: ' *(> ?)?( *)([^\n]*)', replacement: '$3$4'},
            {name: 'table', menu: :table, header_cell: '%{name} ', separator_cell: '--'},
            {name: 'pre', action: 'wrapLines', prefix: "```\n", suffix: "\n```"},
            {name: 'precode', menu: :precode, prefix: "``` %{lang}\n", suffix: "\n```\n"},
            SPACER,
            {name: 'link', action: 'wrap', prefix: '[[', suffix: ']]'},
            {name: 'img', action: 'wrap', prefix: '![](', suffix: ')'},
            SPACER,
            {name: 'help', action: 'help'}
          ]
        end
      end
    end
  end
end
