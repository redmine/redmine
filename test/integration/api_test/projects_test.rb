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

class Redmine::ApiTest::ProjectsTest < Redmine::ApiTest::Base
  include ActiveJob::TestHelper
  def setup
    super
    set_tmp_attachments_directory
  end

  test "GET /projects.xml should return projects" do
    project = Project.find(1)
    project.inherit_members = '1'
    project.save!

    get '/projects.xml'
    assert_response :success
    assert_equal 'application/xml', @response.media_type

    assert_select 'projects>project:first-child' do
      assert_select '>id', :text => '1'
      assert_select '>status', :text => '1'
      assert_select '>is_public', :text => 'true'
      assert_select '>inherit_members', :text => 'true'
      assert_select '>homepage', :text => 'http://ecookbook.somenet.foo/'
    end
  end

  test "GET /projects.json should return projects" do
    get '/projects.json'
    assert_response :success
    assert_equal 'application/json', @response.media_type

    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert_kind_of Array, json['projects']
    assert_kind_of Hash, json['projects'].first
    assert json['projects'].first.has_key?('id')
    assert json['projects'].first.has_key?('inherit_members')
    assert json['projects'].first.has_key?('homepage')
  end

  test "GET /projects.xml with include=issue_categories should return categories" do
    get '/projects.xml?include=issue_categories'
    assert_response :success
    assert_equal 'application/xml', @response.media_type

    assert_select 'issue_categories[type=array] issue_category[id="2"][name=Recipes]'
  end

  test "GET /projects.xml with include=trackers should return trackers" do
    get '/projects.xml?include=trackers'
    assert_response :success
    assert_equal 'application/xml', @response.media_type

    assert_select 'trackers[type=array] tracker[id="2"][name="Feature request"]'
  end

  test "GET /projects.xml with include=enabled_modules should return enabled modules" do
    get '/projects.xml?include=enabled_modules'
    assert_response :success
    assert_equal 'application/xml', @response.media_type

    assert_select 'enabled_modules[type=array] enabled_module[name=issue_tracking]'
  end

  test "GET /projects.xml with include=issue_custom_fields should return custom fields" do
    IssueCustomField.find(6).update_attribute :is_for_all, true
    IssueCustomField.find(8).update_attribute :is_for_all, false
    get '/projects.xml?include=issue_custom_fields'
    assert_response :success
    assert_equal 'application/xml', @response.media_type

    assert_select 'issue_custom_fields[type=array] custom_field[name="Project 1 cf"]'
    # Custom field for all projects
    assert_select 'issue_custom_fields[type=array] custom_field[id="6"]'
    assert_select 'issue_custom_fields[type=array] custom_field[id="8"]', 0
  end

  test "GET /projects/:id.xml should return the project" do
    Project.find(1).update!(:inherit_members => '1')

    get '/projects/1.xml'
    assert_response :success
    assert_equal 'application/xml', @response.media_type

    assert_select 'project>id', :text => '1'
    assert_select 'project>status', :text => '1'
    assert_select 'project>is_public', :text => 'true'
    assert_select 'project>inherit_members', :text => 'true'
    assert_select 'project>homepage', :text => 'http://ecookbook.somenet.foo/'
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
    assert_equal false, json['project']['inherit_members']
    assert_equal false, json['project'].has_key?('default_version')
    assert_equal false, json['project'].has_key?('default_assignee')
    assert_equal 'http://ecookbook.somenet.foo/', json['project']['homepage']
  end

  test "GET /projects/:id.xml with hidden custom fields should not display hidden custom fields" do
    ProjectCustomField.find_by_name('Development status').update_attribute :visible, false

    get '/projects/1.xml'
    assert_response :success
    assert_equal 'application/xml', @response.media_type

    assert_select 'custom_field[name=?]', 'Development status', 0
  end

  test "GET /projects/:id.xml with include=issue_categories should return categories" do
    get '/projects/1.xml?include=issue_categories'
    assert_response :success
    assert_equal 'application/xml', @response.media_type

    assert_select 'issue_categories[type=array] issue_category[id="2"][name=Recipes]'
  end

  test "GET /projects/:id.xml with include=time_entry_activities should return activities" do
    get '/projects/1.xml?include=time_entry_activities'
    assert_response :success
    assert_equal 'application/xml', @response.media_type

    assert_select 'time_entry_activities[type=array] time_entry_activity[id="10"][name=Development]'
  end

  test "GET /projects/:id.xml with include=trackers should return trackers" do
    get '/projects/1.xml?include=trackers'
    assert_response :success
    assert_equal 'application/xml', @response.media_type

    assert_select 'trackers[type=array] tracker[id="2"][name="Feature request"]'
  end

  test "GET /projects/:id.xml with include=trackers should return trackers based on role-based permissioning" do
    project = Project.find(1)
    assert_equal [1, 2, 3], project.tracker_ids

    role = Role.find(3) # Reporter
    role.permissions_all_trackers = {'view_issues' => '0'}
    role.permissions_tracker_ids = {'view_issues' => ['1']}
    role.save!

    user = User.find_by(:login => 'jsmith')
    member = project.members.detect{|m| m.user == user}
    member.roles.delete_all
    member.role_ids = [role.id]
    member.roles.reload
    assert_equal [role.id], member.role_ids

    get '/projects/1.xml?include=trackers', :headers => credentials(user.login)
    assert_response :success
    assert_equal 'application/xml', @response.media_type

    assert_select 'trackers[type=array]' do
      assert_select 'tracker[id="1"]', :count => 1
      assert_select 'tracker[id="2"]', :count => 0
      assert_select 'tracker[id="3"]', :count => 0
    end
  end

  test "GET /projects/:id.xml with include=enabled_modules should return enabled modules" do
    get '/projects/1.xml?include=enabled_modules'
    assert_response :success
    assert_equal 'application/xml', @response.media_type

    assert_select 'enabled_modules[type=array] enabled_module[name=issue_tracking]'
  end

  def test_get_project_with_default_version_and_assignee
    user = User.find(3)
    version = Version.find(1)
    Project.find(1).update!(default_assigned_to_id: user.id, default_version_id: version.id)

    get '/projects/1.json'

    json = ActiveSupport::JSON.decode(response.body)
    assert_kind_of Hash, json
    assert_kind_of Hash, json['project']
    assert_equal 1, json['project']['id']

    assert json['project'].has_key?('default_assignee')
    assert_equal 2, json['project']['default_assignee'].length
    assert_equal user.id, json['project']['default_assignee']['id']
    assert_equal user.name, json['project']['default_assignee']['name']

    assert json['project'].has_key?('default_version')
    assert_equal 2, json['project']['default_version'].length
    assert_equal version.id, json['project']['default_version']['id']
    assert_equal version.name, json['project']['default_version']['name']
  end

  def test_get_project_should_not_load_default_query
    query = ProjectQuery.find(11)
    ProjectQuery.stubs(:default).returns query

    get '/projects.json'

    assert results = JSON.parse(@response.body)['projects']

    assert_equal 4, results.count
    assert results.detect{ |i| i['name'] == "eCookbook"}
  end

  test "POST /projects.xml with valid parameters should create the project" do
    with_settings :default_projects_modules => ['issue_tracking', 'repository'] do
      assert_difference('Project.count') do
        post(
          '/projects.xml',
          :params => {:project => {:name => 'API test', :identifier => 'api-test'}},
          :headers => credentials('admin')
        )
      end
    end

    project = Project.order('id DESC').first
    assert_equal 'API test', project.name
    assert_equal 'api-test', project.identifier
    assert_equal ['issue_tracking', 'repository'], project.enabled_module_names.sort
    assert_equal Tracker.all.size, project.trackers.size

    assert_response :created
    assert_equal 'application/xml', @response.media_type
    assert_select 'project id', :text => project.id.to_s
  end

  test "POST /projects.xml should accept enabled_module_names attribute" do
    assert_difference('Project.count') do
      post(
        '/projects.xml',
        :params => {
          :project => {
            :name => 'API test',
            :identifier => 'api-test',
            :enabled_module_names => ['issue_tracking', 'news', 'time_tracking']
          }
        },
        :headers => credentials('admin')
      )
    end

    project = Project.order('id DESC').first
    assert_equal ['issue_tracking', 'news', 'time_tracking'], project.enabled_module_names.sort
  end

  test "POST /projects.xml should accept tracker_ids attribute" do
    assert_difference('Project.count') do
      post(
        '/projects.xml',
        :params => {
          :project => {
            :name => 'API test',
            :identifier => 'api-test',
            :tracker_ids => [1, 3]
          }
        },
        :headers => credentials('admin')
      )
    end

    project = Project.order('id DESC').first
    assert_equal [1, 3], project.trackers.map(&:id).sort
  end

  test "POST /projects.xml with invalid parameters should return errors" do
    assert_no_difference('Project.count') do
      post(
        '/projects.xml',
        :params => {:project => {:name => 'API test'}},
        :headers => credentials('admin')
      )
    end

    assert_response :unprocessable_content
    assert_equal 'application/xml', @response.media_type
    assert_select 'errors error', :text => "Identifier cannot be blank"
  end

  test "PUT /projects/:id.xml with valid parameters should update the project" do
    assert_no_difference 'Project.count' do
      put(
        '/projects/2.xml',
        :params => {:project => {:name => 'API update'}},
        :headers => credentials('jsmith')
      )
    end
    assert_response :no_content
    assert_equal '', @response.body
    assert_nil @response.media_type
    project = Project.find(2)
    assert_equal 'API update', project.name
  end

  test "PUT /projects/:id.xml should accept enabled_module_names attribute" do
    assert_no_difference 'Project.count' do
      put(
        '/projects/2.xml',
        :params => {
          :project => {
            :name => 'API update',
            :enabled_module_names => ['issue_tracking', 'news', 'time_tracking']
          }
        },
        :headers => credentials('admin')
      )
    end
    assert_response :no_content
    assert_equal '', @response.body
    project = Project.find(2)
    assert_equal ['issue_tracking', 'news', 'time_tracking'], project.enabled_module_names.sort
  end

  test "PUT /projects/:id.xml should accept tracker_ids attribute" do
    assert_no_difference 'Project.count' do
      put(
        '/projects/2.xml',
        :params => {:project => {:name => 'API update', :tracker_ids => [1, 3]}},
        :headers => credentials('admin')
      )
    end
    assert_response :no_content
    assert_equal '', @response.body
    project = Project.find(2)
    assert_equal [1, 3], project.trackers.map(&:id).sort
  end

  test "PUT /projects/:id.xml with invalid parameters should return errors" do
    assert_no_difference('Project.count') do
      put(
        '/projects/2.xml',
        :params => {:project => {:name => ''}},
        :headers => credentials('admin')
      )
    end

    assert_response :unprocessable_content
    assert_equal 'application/xml', @response.media_type
    assert_select 'errors error', :text => "Name cannot be blank"
  end

  test "DELETE /projects/:id.xml should schedule deletion of the project" do
    assert_no_difference('Project.count') do
      delete '/projects/2.xml', :headers => credentials('admin')
    end
    assert_enqueued_with(job: DestroyProjectJob,
                         args: ->(job_args){ job_args[0] == 2})
    assert_response :no_content
    assert_equal '', @response.body
    assert p = Project.find_by_id(2)
    assert_equal Project::STATUS_SCHEDULED_FOR_DELETION, p.status
  end

  test "PUT /projects/:id/archive.xml should archive project" do
    put '/projects/1/archive.xml', :headers => credentials('admin')
    assert_response :no_content
    assert_equal '', @response.body
    assert p = Project.find(1)
    assert_not p.active?
  end

  test "PUT /projects/:id/unarchive.xml should unarchive project" do
    Project.find(1).update_column :status, Project::STATUS_ARCHIVED
    put '/projects/1/unarchive.xml', :headers => credentials('admin')
    assert_response :no_content
    assert_equal '', @response.body
    assert p = Project.find_by_id(2)
    assert p.active?
  end

  test "PUT /projects/:id/close.xml should close project" do
    put '/projects/1/close.xml', :headers => credentials('admin')
    assert_response :no_content
    assert_equal '', @response.body
    assert p = Project.find(1)
    assert p.closed?
  end

  test "PUT /projects/:id/reopen.xml should reopen project" do
    Project.find(1).update_column :status, Project::STATUS_CLOSED
    put '/projects/1/reopen.xml', :headers => credentials('admin')
    assert_response :no_content
    assert_equal '', @response.body
    assert p = Project.find(1)
    assert p.active?
  end

  def queue_adapter_for_test
    ActiveJob::QueueAdapters::TestAdapter.new
  end
end
