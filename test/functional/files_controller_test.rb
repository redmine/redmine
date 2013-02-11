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

require File.expand_path('../../test_helper', __FILE__)

class FilesControllerTest < ActionController::TestCase
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :journals, :journal_details,
           :attachments,
           :versions

  def setup
    @request.session[:user_id] = nil
    Setting.default_language = 'en'
  end

  def test_index
    get :index, :project_id => 1
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:containers)

    # file attached to the project
    assert_tag :a, :content => 'project_file.zip',
                   :attributes => { :href => '/attachments/download/8/project_file.zip' }

    # file attached to a project's version
    assert_tag :a, :content => 'version_file.zip',
                   :attributes => { :href => '/attachments/download/9/version_file.zip' }
  end

  def test_new
    @request.session[:user_id] = 2
    get :new, :project_id => 1
    assert_response :success
    assert_template 'new'

    assert_tag 'select', :attributes => {:name => 'version_id'}
  end

  def test_new_without_versions
    Version.delete_all
    @request.session[:user_id] = 2
    get :new, :project_id => 1
    assert_response :success
    assert_template 'new'

    assert_no_tag 'select', :attributes => {:name => 'version_id'}
  end

  def test_create_file
    set_tmp_attachments_directory
    @request.session[:user_id] = 2
    ActionMailer::Base.deliveries.clear

    with_settings :notified_events => %w(file_added) do
      assert_difference 'Attachment.count' do
        post :create, :project_id => 1, :version_id => '',
             :attachments => {'1' => {'file' => uploaded_test_file('testfile.txt', 'text/plain')}}
        assert_response :redirect
      end
    end
    assert_redirected_to '/projects/ecookbook/files'
    a = Attachment.order('created_on DESC').first
    assert_equal 'testfile.txt', a.filename
    assert_equal Project.find(1), a.container

    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_equal "[eCookbook] New file", mail.subject
    assert_mail_body_match 'testfile.txt', mail
  end

  def test_create_version_file
    set_tmp_attachments_directory
    @request.session[:user_id] = 2

    assert_difference 'Attachment.count' do
      post :create, :project_id => 1, :version_id => '2',
           :attachments => {'1' => {'file' => uploaded_test_file('testfile.txt', 'text/plain')}}
      assert_response :redirect
    end
    assert_redirected_to '/projects/ecookbook/files'
    a = Attachment.order('created_on DESC').first
    assert_equal 'testfile.txt', a.filename
    assert_equal Version.find(2), a.container
  end

end
