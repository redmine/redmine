# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class Redmine::ApiTest::ProjectsTest < Redmine::ApiTest::Base
  fixtures :projects, :versions, :users, :roles, :members, :member_roles, :issues, :journals, :journal_details,
           :trackers, :projects_trackers, :issue_statuses, :enabled_modules, :enumerations, :boards, :messages,
           :attachments, :custom_fields, :custom_values, :time_entries, :issue_categories

  def setup
    super
    set_tmp_attachments_directory
  end

  test "GET /projects.xml should return projects" do
    get '/projects.xml'
    assert_response :success
    assert_equal 'application/xml', @response.content_type

    assert_select 'projects>project>id', :text => '1'
    assert_select 'projects>project>status', :text => '1'
    assert_select 'projects>project>is_public', :text => 'true'
  end

  test "GET /projects.json should return projects" do
    get '/projects.json'
    assert_response :success
    assert_equal 'application/json', @response.content_type

    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert_kind_of Array, json['projects']
    assert_kind_of Hash, json['projects'].first
    assert json['projects'].first.has_key?('id')
  end

  test "GET /projects.xml with include=issue_categories should return categories" do
    get '/projects.xml?include=issue_categories'
    assert_response :success
    assert_equal 'application/xml', @response.content_type

    assert_select 'issue_categories[type=array] issue_category[id="2"][name=Recipes]'
  end

  test "GET /projects.xml with include=trackers should return trackers" do
    get '/projects.xml?include=trackers'
    assert_response :success
    assert_equal 'application/xml', @response.content_type

    assert_select 'trackers[type=array] tracker[id="2"][name="Feature request"]'
  end

  test "GET /projects.xml with include=enabled_modules should return enabled modules" do
    get '/projects.xml?include=enabled_modules'
    assert_response :success
    assert_equal 'application/xml', @response.content_type

    assert_select 'enabled_modules[type=array] enabled_module[name=issue_tracking]'
  end

  test "GET /projects/:id.xml should return the project" do
    get '/projects/1.xml'
    assert_response :success
    assert_equal 'application/xml', @response.content_type

    assert_select 'project>id', :text => '1'
    assert_select 'project>status', :text => '1'
    assert_select 'project>is_public', :text => 'true'
    assert_select 'custom_field[name="Development status"]', :text => 'Stable'

    assert_select 'trackers', 0
    assert_select 'issue_categories', 0
  end

  test "GET /projects/:id.json should return the project" do
    get '/projects/1.json'

    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert_kind_of Hash, json['project']
    assert_equal 1, json['project']['id']
  end

  test "GET /projects/:id.xml with hidden custom fields should not display hidden custom fields" do
    ProjectCustomField.find_by_name('Development status').update_attribute :visible, false

    get '/projects/1.xml'
    assert_response :success
    assert_equal 'application/xml', @response.content_type

    assert_select 'custom_field[name=?]', 'Development status', 0
  end

  test "GET /projects/:id.xml with include=issue_categories should return categories" do
    get '/projects/1.xml?include=issue_categories'
    assert_response :success
    assert_equal 'application/xml', @response.content_type

    assert_select 'issue_categories[type=array] issue_category[id="2"][name=Recipes]'
  end

  test "GET /projects/:id.xml with include=trackers should return trackers" do
    get '/projects/1.xml?include=trackers'
    assert_response :success
    assert_equal 'application/xml', @response.content_type

    assert_select 'trackers[type=array] tracker[id="2"][name="Feature request"]'
  end

  test "GET /projects/:id.xml with include=enabled_modules should return enabled modules" do
    get '/projects/1.xml?include=enabled_modules'
    assert_response :success
    assert_equal 'application/xml', @response.content_type

    assert_select 'enabled_modules[type=array] enabled_module[name=issue_tracking]'
  end

  test "POST /projects.xml with valid parameters should create the project" do
    with_settings :default_projects_modules => ['issue_tracking', 'repository'] do
      assert_difference('Project.count') do
        post '/projects.xml',
          {:project => {:name => 'API test', :identifier => 'api-test'}},
          credentials('admin')
      end
    end

    project = Project.order('id DESC').first
    assert_equal 'API test', project.name
    assert_equal 'api-test', project.identifier
    assert_equal ['issue_tracking', 'repository'], project.enabled_module_names.sort
    assert_equal Tracker.all.size, project.trackers.size

    assert_response :created
    assert_equal 'application/xml', @response.content_type
    assert_select 'project id', :text => project.id.to_s
  end

  test "POST /projects.xml should accept enabled_module_names attribute" do
    assert_difference('Project.count') do
      post '/projects.xml',
        {:project => {:name => 'API test', :identifier => 'api-test', :enabled_module_names => ['issue_tracking', 'news', 'time_tracking']}},
        credentials('admin')
    end

    project = Project.order('id DESC').first
    assert_equal ['issue_tracking', 'news', 'time_tracking'], project.enabled_module_names.sort
  end

  test "POST /projects.xml should accept tracker_ids attribute" do
    assert_difference('Project.count') do
      post '/projects.xml',
        {:project => {:name => 'API test', :identifier => 'api-test', :tracker_ids => [1, 3]}},
        credentials('admin')
    end

    project = Project.order('id DESC').first
    assert_equal [1, 3], project.trackers.map(&:id).sort
  end

  test "POST /projects.xml with invalid parameters should return errors" do
    assert_no_difference('Project.count') do
      post '/projects.xml', {:project => {:name => 'API test'}}, credentials('admin')
    end

    assert_response :unprocessable_entity
    assert_equal 'application/xml', @response.content_type
    assert_select 'errors error', :text => "Identifier cannot be blank"
  end

  test "PUT /projects/:id.xml with valid parameters should update the project" do
    assert_no_difference 'Project.count' do
      put '/projects/2.xml', {:project => {:name => 'API update'}}, credentials('jsmith')
    end
    assert_response :ok
    assert_equal '', @response.body
    assert_equal 'application/xml', @response.content_type
    project = Project.find(2)
    assert_equal 'API update', project.name
  end

  test "PUT /projects/:id.xml should accept enabled_module_names attribute" do
    assert_no_difference 'Project.count' do
      put '/projects/2.xml', {:project => {:name => 'API update', :enabled_module_names => ['issue_tracking', 'news', 'time_tracking']}}, credentials('admin')
    end
    assert_response :ok
    assert_equal '', @response.body
    project = Project.find(2)
    assert_equal ['issue_tracking', 'news', 'time_tracking'], project.enabled_module_names.sort
  end

  test "PUT /projects/:id.xml should accept tracker_ids attribute" do
    assert_no_difference 'Project.count' do
      put '/projects/2.xml', {:project => {:name => 'API update', :tracker_ids => [1, 3]}}, credentials('admin')
    end
    assert_response :ok
    assert_equal '', @response.body
    project = Project.find(2)
    assert_equal [1, 3], project.trackers.map(&:id).sort
  end

  test "PUT /projects/:id.xml with invalid parameters should return errors" do
    assert_no_difference('Project.count') do
      put '/projects/2.xml', {:project => {:name => ''}}, credentials('admin')
    end

    assert_response :unprocessable_entity
    assert_equal 'application/xml', @response.content_type
    assert_select 'errors error', :text => "Name cannot be blank"
  end

  test "DELETE /projects/:id.xml should delete the project" do
    assert_difference('Project.count',-1) do
      delete '/projects/2.xml', {}, credentials('admin')
    end
    assert_response :ok
    assert_equal '', @response.body
    assert_nil Project.find_by_id(2)
  end
end
