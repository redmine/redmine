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
      # fixes:
      # - autolinked email addresses that are actually references to users:
      #   user:<a href="mailto:user@example.org">user@example.org</a>
      #   @<a href="mailto:user@example.org">user@example.org</a>
      # - autolinked hi res image names that look like email addresses:
      #   <a href="mailto:printscreen@2x.png">printscreen@2x.png</a>
      class FixupAutoLinksFilter < HTML::Pipeline::Filter
        USER_LINK_PREFIX = /(@|user:)\z/.freeze
        HIRES_IMAGE = /.+@\dx\.(bmp|gif|jpg|jpe|jpeg|png)\z/.freeze

        def call
          doc.search("a").each do |node|
            unless (url = node['href']) && url.starts_with?('mailto:')
              next
            end

            if ((p = node.previous) && p.text? &&
                p.text =~(USER_LINK_PREFIX)) ||
               (node.text =~ HIRES_IMAGE)

              node.replace node.text
            end
          end
          doc
        end
      end
    end
  end
end
