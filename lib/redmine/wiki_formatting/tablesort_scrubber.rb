# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
# This code is released under the GNU General Public License.

module Redmine
  module WikiFormatting
    class TablesortScrubber < Loofah::Scrubber
      def scrub(node)
        return if !Setting.wiki_tablesort_enabled? || node.name != 'table'

        rows = node.search('tr')
        return if rows.size < 3

        tr = rows.first
        if tr.search('th').present?
          node['data-controller'] = 'tablesort'
          tr['data-sort-method']  = 'none'
          tr.search('td').each do |td|
            td['data-sort-method'] = 'none'
          end
        end
      end
    end
  end
end
