# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

class ImportsControllerTest < ActionController::TestCase
  fixtures :projects, :enabled_modules,
           :users, :email_addresses,
           :roles, :members, :member_roles,
           :issues, :issue_statuses,
           :trackers, :projects_trackers,
           :versions,
           :issue_categories,
           :enumerations,
           :workflows,
           :custom_fields,
           :custom_values,
           :custom_fields_projects,
           :custom_fields_trackers

  def setup
    User.current = nil
    @request.session[:user_id] = 2
  end

  def teardown
    Import.destroy_all
  end

  def test_new_should_display_the_upload_form
    get :new
    assert_response :success
    assert_template 'new'
    assert_select 'input[name=?]', 'file'
  end

  def test_create_should_save_the_file
    import = new_record(Import) do
      post :create, :file => uploaded_test_file('import_issues.csv', 'text/csv')
      assert_response 302
    end
    assert_equal 2, import.user_id
    assert_match /\A[0-9a-f]+\z/, import.filename
    assert import.file_exists?
  end

  def test_get_settings_should_display_settings_form
    import = generate_import
    get :settings, :id => import.to_param
    assert_response :success
    assert_template 'settings'
  end

  def test_post_settings_should_update_settings
    import = generate_import

    post :settings, :id => import.to_param,
      :import_settings => {:separator => ":", :wrapper => "|", :encoding => "UTF-8", :date_format => '%m/%d/%Y'}
    assert_redirected_to "/imports/#{import.to_param}/mapping"

    import.reload
    assert_equal ":", import.settings['separator']
    assert_equal "|", import.settings['wrapper']
    assert_equal "UTF-8", import.settings['encoding']
    assert_equal '%m/%d/%Y', import.settings['date_format']
  end

  def test_post_settings_should_update_total_items_count
    import = generate_import('import_iso8859-1.csv')

    post :settings, :id => import.to_param,
      :import_settings => {:separator => ";", :wrapper => '"', :encoding => "ISO-8859-1"}
    assert_response 302
    import.reload
    assert_equal 2, import.total_items
  end

  def test_post_settings_with_wrong_encoding_should_display_error
    import = generate_import('import_iso8859-1.csv')

    post :settings, :id => import.to_param,
      :import_settings => {:separator => ";", :wrapper => '"', :encoding => "UTF-8"}
    assert_response 200
    import.reload
    assert_nil import.total_items
    assert_select 'div#flash_error', /not a valid UTF-8 encoded file/
  end

  def test_get_mapping_should_display_mapping_form
    import = generate_import('import_iso8859-1.csv')
    import.settings = {'separator' => ";", 'wrapper' => '"', 'encoding' => "ISO-8859-1"}
    import.save!

    get :mapping, :id => import.to_param
    assert_response :success
    assert_template 'mapping'

    assert_select 'select[name=?]', 'import_settings[mapping][subject]' do
      assert_select 'option', 4
      assert_select 'option[value="0"]', :text => 'column A'
    end

    assert_select 'table.sample-data' do
      assert_select 'tr', 3
      assert_select 'td', 9
    end
  end

  def test_post_mapping_should_update_mapping
    import = generate_import('import_iso8859-1.csv')

    post :mapping, :id => import.to_param,
      :import_settings => {:mapping => {:project_id => '1', :tracker_id => '2', :subject => '0'}}
    assert_redirected_to "/imports/#{import.to_param}/run"
    import.reload
    mapping = import.settings['mapping']
    assert mapping
    assert_equal '1', mapping['project_id']
    assert_equal '2', mapping['tracker_id']
    assert_equal '0', mapping['subject']
  end
 
  def test_get_run
    import = generate_import_with_mapping

    get :run, :id => import
    assert_response :success
    assert_template 'run'
  end
 
  def test_post_run_should_import_the_file
    import = generate_import_with_mapping

    assert_difference 'Issue.count', 3 do
      post :run, :id => import
      assert_redirected_to "/imports/#{import.to_param}"
    end

    import.reload
    assert_equal true, import.finished
    assert_equal 3, import.items.count

    issues = Issue.order(:id => :desc).limit(3).to_a
    assert_equal ["Child of existing issue", "Child 1", "First"], issues.map(&:subject)
  end

  def test_post_run_should_import_max_items_and_resume
    ImportsController.any_instance.stubs(:max_items_per_request).returns(2)
    import = generate_import_with_mapping

    assert_difference 'Issue.count', 2 do
      post :run, :id => import
      assert_redirected_to "/imports/#{import.to_param}/run"
    end

    assert_difference 'Issue.count', 1 do
      post :run, :id => import
      assert_redirected_to "/imports/#{import.to_param}"
    end

    issues = Issue.order(:id => :desc).limit(3).to_a
    assert_equal ["Child of existing issue", "Child 1", "First"], issues.map(&:subject)
  end

  def test_show_without_errors
    import = generate_import_with_mapping
    import.run
    assert_equal 0, import.unsaved_items.count

    get :show, :id => import.to_param
    assert_response :success
    assert_template 'show'
    assert_select 'table#unsaved-items', 0
  end

  def test_show_with_errors_should_show_unsaved_items
    import = generate_import_with_mapping
    import.mapping.merge! 'subject' => 20
    import.run
    assert_not_equal 0, import.unsaved_items.count

    get :show, :id => import.to_param
    assert_response :success
    assert_template 'show'
    assert_select 'table#unsaved-items'
  end
end
