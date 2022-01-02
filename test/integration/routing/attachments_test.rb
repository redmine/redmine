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

require File.expand_path('../../../test_helper', __FILE__)

class RoutingAttachmentsTest < Redmine::RoutingTest
  def test_attachments
    should_route 'GET /attachments/1' => 'attachments#show', :id => '1'
    should_route 'GET /attachments/1/filename.ext' => 'attachments#show', :id => '1', :filename => 'filename.ext', :format => 'html'
    should_route 'GET /attachments/1/filename.txt' => 'attachments#show', :id => '1', :filename => 'filename.txt', :format => 'html'

    should_route 'GET /attachments/download/1' => 'attachments#download', :id => '1'
    should_route 'GET /attachments/download/1/filename.ext' => 'attachments#download', :id => '1', :filename => 'filename.ext'

    should_route 'GET /attachments/thumbnail/1' => 'attachments#thumbnail', :id => '1'
    should_route 'GET /attachments/thumbnail/1/200' => 'attachments#thumbnail', :id => '1', :size => '200'

    should_route 'DELETE /attachments/1' => 'attachments#destroy', :id => '1'

    should_route 'GET /attachments/issues/1/edit' => 'attachments#edit_all', :object_type => 'issues', :object_id => '1'
    should_route 'PATCH /attachments/issues/1' => 'attachments#update_all', :object_type => 'issues', :object_id => '1'
    should_route 'GET /attachments/issues/1/download' => 'attachments#download_all', :object_type => 'issues', :object_id => '1'
  end
end
