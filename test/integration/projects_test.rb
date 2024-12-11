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

require_relative '../test_helper'

class ProjectsTest < Redmine::IntegrationTest
  def test_archive_project
    subproject = Project.find(1).children.first
    log_user("admin", "admin")
    get "/admin/projects"
    assert_response :success

    post "/projects/1/archive"
    assert_redirected_to "/admin/projects"
    assert !Project.find(1).active?

    get '/projects/1'
    assert_response :forbidden
    get "/projects/#{subproject.id}"
    assert_response :forbidden

    post "/projects/1/unarchive"
    assert_redirected_to "/admin/projects"
    assert Project.find(1).active?
    get "/projects/1"
    assert_response :success
  end

  def test_modules_should_not_allow_get
    log_user("admin", "admin")

    assert_no_difference 'EnabledModule.count' do
      get '/projects/1/modules', :params => {:enabled_module_names => ['']}
      assert_response :not_found
    end
  end

  def test_list_layout_when_show_projects_scheduled_for_deletion
    project = Project.find(1)
    project.update_attribute :status, Project::STATUS_SCHEDULED_FOR_DELETION

    log_user('admin', 'admin')

    get '/admin/projects', :params => { :f => ['status'], :v => { 'status' => ['10'] } }
    assert_response :success

    assert_select '#project-1' do
      assert_select 'td.checkbox.hide-when-print'
      assert_select 'td.name'
      assert_select 'td.identifier'
      assert_select 'td.short_description'
      assert_select 'td.buttons', text: ''
    end
  end
end
