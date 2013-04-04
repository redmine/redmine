# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

require File.expand_path('../../../test_helper', __FILE__)

class RoutingCommentsTest < ActionController::IntegrationTest
  def test_comments
    assert_routing(
        { :method => 'post', :path => "/news/567/comments" },
        { :controller => 'comments', :action => 'create', :id => '567' }
      )
    assert_routing(
        { :method => 'delete', :path => "/news/567/comments/15" },
        { :controller => 'comments', :action => 'destroy', :id => '567',
          :comment_id => '15' }
      )
  end
end
