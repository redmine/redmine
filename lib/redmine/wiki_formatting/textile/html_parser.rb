# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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
      class HtmlParser < Redmine::WikiFormatting::HtmlParser

        self.tags = tags.merge(
          'b' => {:pre => '*', :post => '*'},
          'strong' => {:pre => '*', :post => '*'},
          'i' => {:pre => '_', :post => '_'},
          'em' => {:pre => '_', :post => '_'},
          'u' => {:pre => '+', :post => '+'},
          'strike' => {:pre => '-', :post => '-'},
          'h1' => {:pre => "\n\nh1. ", :post => "\n\n"},
          'h2' => {:pre => "\n\nh2. ", :post => "\n\n"},
          'h3' => {:pre => "\n\nh3. ", :post => "\n\n"},
          'h4' => {:pre => "\n\nh4. ", :post => "\n\n"},
          'h5' => {:pre => "\n\nh5. ", :post => "\n\n"},
          'h6' => {:pre => "\n\nh6. ", :post => "\n\n"}
        )
      end
    end
  end
end
