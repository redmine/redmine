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

require_relative '../../test_helper'

class RoutingHelpTest < Redmine::RoutingTest
  def test_help
    should_route 'GET /help/wiki_syntax' => 'help#show_wiki_syntax'
    should_route 'GET /help/wiki_syntax/detailed' => 'help#show_wiki_syntax', :type => "detailed"

    should_route 'GET /help/code_highlighting' => 'help#show_code_highlighting'
  end
end
