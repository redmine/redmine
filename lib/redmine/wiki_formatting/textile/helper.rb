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
    module Textile
      module Helper
        include Redmine::WikiToolbar::Helper

        def wiki_toolbar
          @wiki_toolbar ||= WikiToolbar.new(self)
        end

        def initial_page_content(page)
          "h1. #{page.pretty_title}"
        end
      end

      class WikiToolbar < Redmine::WikiToolbar
        def format
          'textile'
        end

        def button_groups
          [
            %w[strong em ins del code],
            %w[h1 h2 h3],
            %w[ul ol],
            %w[bq unbq table pre precode],
            %w[link img],
            %w[help]
          ]
        end
      end
    end
  end
end
