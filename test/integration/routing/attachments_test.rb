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

class RoutingAttachmentsTest < ActionController::IntegrationTest
  def test_attachments
    assert_routing(
           { :method => 'get', :path => "/attachments/1" },
           { :controller => 'attachments', :action => 'show', :id => '1' }
         )
    assert_routing(
           { :method => 'get', :path => "/attachments/1.xml" },
           { :controller => 'attachments', :action => 'show', :id => '1', :format => 'xml' }
         )
    assert_routing(
           { :method => 'get', :path => "/attachments/1.json" },
           { :controller => 'attachments', :action => 'show', :id => '1', :format => 'json' }
         )
    assert_routing(
           { :method => 'get', :path => "/attachments/1/filename.ext" },
           { :controller => 'attachments', :action => 'show', :id => '1',
             :filename => 'filename.ext' }
         )
    assert_routing(
           { :method => 'get', :path => "/attachments/download/1" },
           { :controller => 'attachments', :action => 'download', :id => '1' }
         )
    assert_routing(
           { :method => 'get', :path => "/attachments/download/1/filename.ext" },
           { :controller => 'attachments', :action => 'download', :id => '1',
             :filename => 'filename.ext' }
         )
    assert_routing(
           { :method => 'get', :path => "/attachments/thumbnail/1" },
           { :controller => 'attachments', :action => 'thumbnail', :id => '1' }
         )
    assert_routing(
           { :method => 'get', :path => "/attachments/thumbnail/1/200" },
           { :controller => 'attachments', :action => 'thumbnail', :id => '1', :size => '200' }
         )
    assert_routing(
           { :method => 'delete', :path => "/attachments/1" },
           { :controller => 'attachments', :action => 'destroy', :id => '1' }
         )
    assert_routing(
           { :method => 'post', :path => '/uploads.xml' },
           { :controller => 'attachments', :action => 'upload', :format => 'xml' }
    )
    assert_routing(
           { :method => 'post', :path => '/uploads.json' },
           { :controller => 'attachments', :action => 'upload', :format => 'json' }
    )
  end
end
