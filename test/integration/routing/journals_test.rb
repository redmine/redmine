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

class RoutingJournalsTest < ActionController::IntegrationTest
  def test_journals
    assert_routing(
        { :method => 'post', :path => "/issues/1/quoted" },
        { :controller => 'journals', :action => 'new', :id => '1' }
      )
    assert_routing(
        { :method => 'get', :path => "/issues/changes" },
        { :controller => 'journals', :action => 'index' }
      )
    assert_routing(
        { :method => 'get', :path => "/journals/diff/1" },
        { :controller => 'journals', :action => 'diff', :id => '1' }
      )
    ["get", "post"].each do |method|
      assert_routing(
          { :method => method, :path => "/journals/edit/1" },
          { :controller => 'journals', :action => 'edit', :id => '1' }
        )
    end
  end
end
