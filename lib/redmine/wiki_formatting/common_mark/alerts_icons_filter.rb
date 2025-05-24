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
      # Defines the mapping from alert type (from CSS class) to SVG icon name.
      # These icon names must correspond to IDs in your SVG sprite sheet (e.g., icons.svg).
      ALERT_TYPE_TO_ICON_NAME = {
        'note' => 'help',
        'tip' => 'bulb',
        'warning' => 'warning',
        'caution' => 'alert-circle',
        'important' => 'message-report',
      }.freeze

      class AlertsIconsFilter < HTML::Pipeline::Filter
        def call
          doc.search("p.markdown-alert-title").each do |node|
            parent_node = node.parent
            parent_class_attr = parent_node['class'] # e.g., "markdown-alert markdown-alert-note"
            next unless parent_class_attr

            # Extract the specific alert type (e.g., "note", "tip", "warning")
            # from the parent div's classes.
            match_data = parent_class_attr.match(/markdown-alert-(\w+)/)
            next unless match_data && match_data[1] # Ensure a type is found

            alert_type = match_data[1]

            # Get the corresponding icon name from our map.
            icon_name = ALERT_TYPE_TO_ICON_NAME[alert_type]
            next unless icon_name # Skip if no specific icon is defined for this alert type

            icon_html = ApplicationController.helpers.sprite_icon(icon_name, node.text)

            if icon_html
              # Replace the existing text node with the icon HTML and label (text).
              node.children.first.replace(icon_html)
            end
          end
          doc
        end
      end
    end
  end
end
