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

class RoutingDocumentsTest < ActionController::IntegrationTest
  def test_documents_scoped_under_project
    assert_routing(
        { :method => 'get', :path => "/projects/567/documents" },
        { :controller => 'documents', :action => 'index', :project_id => '567' }
      )
    assert_routing(
        { :method => 'get', :path => "/projects/567/documents/new" },
        { :controller => 'documents', :action => 'new', :project_id => '567' }
      )
    assert_routing(
        { :method => 'post', :path => "/projects/567/documents" },
        { :controller => 'documents', :action => 'create', :project_id => '567' }
      )
  end

  def test_documents
    assert_routing(
        { :method => 'get', :path => "/documents/22" },
        { :controller => 'documents', :action => 'show', :id => '22' }
      )
    assert_routing(
        { :method => 'get', :path => "/documents/22/edit" },
        { :controller => 'documents', :action => 'edit', :id => '22' }
      )
    assert_routing(
        { :method => 'put', :path => "/documents/22" },
        { :controller => 'documents', :action => 'update', :id => '22' }
      )
    assert_routing(
        { :method => 'delete', :path => "/documents/22" },
        { :controller => 'documents', :action => 'destroy', :id => '22' }
      )
    assert_routing(
        { :method => 'post', :path => "/documents/22/add_attachment" },
        { :controller => 'documents', :action => 'add_attachment', :id => '22' }
      )
  end
end
