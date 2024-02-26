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

class RoutingAdminTest < Redmine::RoutingTest
  def test_administration_panel
    should_route 'GET /admin' => 'admin#index'
    should_route 'GET /admin/projects' => 'admin#projects'
    should_route 'GET /admin/plugins' => 'admin#plugins'
    should_route 'GET /admin/info' => 'admin#info'
    should_route 'POST /admin/test_email' => 'admin#test_email'
    should_route 'POST /admin/default_configuration' => 'admin#default_configuration'
  end
end
