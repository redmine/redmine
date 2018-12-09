# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

class RoutingDocumentsTest < Redmine::RoutingTest
  def test_documents_scoped_under_project
    should_route 'GET /projects/567/documents' => 'documents#index', :project_id => '567'
    should_route 'GET /projects/567/documents/new' => 'documents#new', :project_id => '567'
    should_route 'POST /projects/567/documents' => 'documents#create', :project_id => '567'
  end

  def test_documents
    should_route 'GET /documents/22' => 'documents#show', :id => '22'
    should_route 'GET /documents/22/edit' => 'documents#edit', :id => '22'
    should_route 'PUT /documents/22' => 'documents#update', :id => '22'
    should_route 'DELETE /documents/22' => 'documents#destroy', :id => '22'
  end

  def test_document_attachments
    should_route 'POST /documents/22/add_attachment' => 'documents#add_attachment', :id => '22'
  end
end
