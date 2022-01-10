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

require File.expand_path('../../test_helper', __FILE__)

class ImportsControllerTest < Redmine::ControllerTest
  fixtures :projects, :enabled_modules,
           :users, :email_addresses, :user_preferences,
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

  include Redmine::I18n

  def setup
    User.current = nil
    @request.session[:user_id] = 2
  end

  def teardown
    Import.destroy_all
  end

  def test_new_should_display_the_upload_form
    get(:new, :params => {:type => 'IssueImport', :project_id => 'subproject1'})
    assert_response :success
    assert_select 'input[name=?]', 'file'
    assert_select 'input[name=?][type=?][value=?]', 'project_id', 'hidden', 'subproject1'
  end

  def test_create_should_save_the_file
    import = new_record(Import) do
      post(
        :create,
        :params => {
          :type => 'IssueImport',
          :file => uploaded_test_file('import_issues.csv', 'text/csv')
        }
      )
      assert_response 302
    end
    assert_equal 2, import.user_id
    assert_match /\A[0-9a-f]+\z/, import.filename
    assert import.file_exists?
  end

  def test_get_settings_should_display_settings_form
    import = generate_import
    get(:settings, :params => {:id => import.to_param})
    assert_response :success
    assert_select 'select[name=?]', 'import_settings[separator]'
    assert_select 'select[name=?]', 'import_settings[wrapper]'
    assert_select 'select[name=?]', 'import_settings[encoding]' do
      encodings = valid_languages.map do |lang|
        ll(lang.to_s, :general_csv_encoding)
      end.uniq
      encodings.each do |encoding|
        assert_select 'option[value=?]', encoding
      end
    end
    assert_select 'select[name=?]', 'import_settings[date_format]'
  end

  def test_post_settings_should_update_settings
    import = generate_import

    post(
      :settings,
      :params => {
        :id => import.to_param,
        :import_settings => {
          :separator => ":",
          :wrapper => "|",
          :encoding => "UTF-8",
          :date_format => '%m/%d/%Y'
        }
      }
    )
    assert_redirected_to "/imports/#{import.to_param}/mapping"

    import.reload
    assert_equal ":", import.settings['separator']
    assert_equal "|", import.settings['wrapper']
    assert_equal "UTF-8", import.settings['encoding']
    assert_equal '%m/%d/%Y', import.settings['date_format']
  end

  def test_post_settings_should_update_total_items_count
    import = generate_import('import_iso8859-1.csv')

    post(
      :settings,
      :params => {
        :id => import.to_param,
        :import_settings => {
          :separator => ";",
          :wrapper => '"',
          :encoding => "ISO-8859-1"
        }
      }
    )
    assert_response 302
    import.reload
    assert_equal 2, import.total_items
  end

  def test_post_settings_with_wrong_encoding_should_display_error
    import = generate_import('import_iso8859-1.csv')

    post(
      :settings,
      :params => {
        :id => import.to_param,
        :import_settings => {
          :separator => ";",
          :wrapper => '"',
          :encoding => "UTF-8"
        }
      }
    )
    assert_response 200
    import.reload
    assert_nil import.total_items
    assert_select 'div#flash_error', /not a valid UTF-8 encoded file/
  end

  def test_post_settings_with_invalid_encoding_should_display_error
    import = generate_import('invalid-Shift_JIS.csv')

    post(
      :settings,
      :params => {
        :id => import.to_param,
        :import_settings => {
          :separator => ";",
          :wrapper => '"',
          :encoding => "Shift_JIS"
        }
      }
    )
    assert_response 200
    import.reload
    assert_nil import.total_items
    assert_select 'div#flash_error', /not a valid Shift_JIS encoded file/
  end

  def test_post_settings_with_mailformed_csv_should_display_error
    import = generate_import('unclosed_quoted_field.csv')

    post(
      :settings,
      :params => {
        :id => import.to_param,
        :import_settings => {
          :separator => ';',
          :wrapper => '"',
          :encoding => 'US-ASCII'
        }
      }
    )
    assert_response 200
    import.reload
    assert_nil import.total_items

    assert_select 'div#flash_error', /The file is not a CSV file or does not match the settings below \([[:print:]]+\)/
  end

  def test_post_settings_with_no_data_row_should_display_error
    import = generate_import('import_issues_no_data_row.csv')

    post(
      :settings,
      :params => {
        :id => import.to_param,
        :import_settings => {
          :separator => ';',
          :wrapper => '"',
          :encoding => 'ISO-8859-1'
        }
      }
    )
    assert_response 200
    import.reload
    assert_equal 0, import.total_items

    assert_select 'div#flash_error', /The file does not contain any data/
  end

  def test_get_mapping_should_display_mapping_form
    import = generate_import('import_iso8859-1.csv')
    import.settings = {'separator' => ";", 'wrapper' => '"', 'encoding' => "ISO-8859-1"}
    import.save!

    get(:mapping, :params => {:id => import.to_param})
    assert_response :success

    assert_select 'select[name=?]', 'import_settings[mapping][subject]' do
      assert_select 'option', 4
      assert_select 'option[value="0"]', :text => 'column A'
    end

    assert_select 'table.sample-data' do
      assert_select 'tr', 3
      assert_select 'td', 9
    end
  end

  def test_get_mapping_should_auto_map_fields_by_internal_field_name_or_by_label
    import = generate_import('import_issues_auto_mapping.csv')
    import.settings = {'separator' => ';', 'wrapper'=> '"', 'encoding' => 'ISO-8859-1'}
    import.save!

    get(:mapping, :params => {:id => import.to_param})
    assert_response :success

    # 'subject' should be auto selected because
    #  - 'Subject' exists in the import file
    #  - mapping is case insensitive
    assert_select 'select[name=?]', 'import_settings[mapping][subject]' do
      assert_select 'option[value="1"][selected="selected"]', :text => 'Subject'
    end

    # 'estimated_hours' should be auto selected because
    #  - 'estimated_hours' exists in the import file
    assert_select 'select[name=?]', 'import_settings[mapping][estimated_hours]' do
      assert_select 'option[value="10"][selected="selected"]', :text => 'estimated_hours'
    end

    # 'fixed_version' should be auto selected because
    #  - the translation 'Target version' exists in the import file
    assert_select 'select[name=?]', 'import_settings[mapping][fixed_version]' do
      assert_select 'option[value="7"][selected="selected"]', :text => 'target version'
    end

    # 'assigned_to' should not be auto selected because
    #  - 'assigned_to' does not exist in the import file
    assert_select 'select[name=?]', 'import_settings[mapping][assigned_to]' do
      assert_select 'option[selected="selected"]', 0
    end

    # Custom field 'Float field' should be auto selected because
    #  - the internal field name ('cf_6') exists in the import file
    assert_select 'select[name=?]', 'import_settings[mapping][cf_6]' do
      assert_select 'option[value="14"][selected="selected"]', :text => 'cf_6'
    end

    # Custom field 'Database' should be auto selected because
    #  - field name 'database' exists in the import file
    #  - mapping is case insensitive
    assert_select 'select[name=?]', 'import_settings[mapping][cf_1]' do
      assert_select 'option[value="13"][selected="selected"]', :text => 'database'
    end

    # 'unique_id' should be auto selected because
    # - 'unique_id' exists in the import file
    assert_select 'select[name=?]', 'import_settings[mapping][unique_id]' do
      assert_select 'option[value="15"][selected="selected"]', :text => 'unique_id'
    end

    # 'relation_duplicates' should be auto selected because
    # - 'Is duplicate of' exists in the import file
    assert_select 'select[name=?]', 'import_settings[mapping][relation_duplicates]' do
      assert_select 'option[value="16"][selected="selected"]', :text => 'Is duplicate of'
    end
  end

  def test_post_mapping_should_update_mapping
    import = generate_import('import_iso8859-1.csv')

    post(
      :mapping,
      :params => {
        :id => import.to_param,
        :import_settings => {
          :mapping => {
            :project_id => '1',
            :tracker_id => '2',
            :subject => '0'
          }
        }
      }
    )
    assert_redirected_to "/imports/#{import.to_param}/run"
    import.reload
    mapping = import.settings['mapping']
    assert mapping
    assert_equal '1', mapping['project_id']
    assert_equal '2', mapping['tracker_id']
    assert_equal '0', mapping['subject']
  end

  def test_get_mapping_time_entry
    Role.find(1).add_permission! :log_time_for_other_users
    import = generate_time_entry_import
    import.settings = {'separator' => ";", 'wrapper' => '"', 'encoding' => "ISO-8859-1"}
    import.save!

    get(:mapping, :params => {:id => import.to_param})

    assert_response :success

    # Assert auto mapped fields
    assert_select 'select[name=?]', 'import_settings[mapping][activity]' do
      assert_select 'option[value="5"][selected="selected"]', :text => 'activity'
    end
    # 'user' should be mapped to column 'user' from import file
    # and not to current user because the auto map has priority
    assert_select 'select[name=?]', 'import_settings[mapping][user]' do
      assert_select 'option[value="7"][selected="selected"]', :text => 'user'
    end
    assert_select 'select[name=?]', 'import_settings[mapping][cf_10]' do
      assert_select 'option[value="6"][selected="selected"]', :text => 'overtime'
    end
  end

  def test_get_mapping_time_entry_for_user_with_log_time_for_other_users_permission
    Role.find(1).add_permission! :log_time_for_other_users
    import = generate_time_entry_import
    import.settings = {
      'separator' => ";", 'wrapper' => '"', 'encoding' => "ISO-8859-1",
      # Do not auto map user in order to allow current user to be auto selected
      'mapping' => {'user' => nil}
    }
    import.save!

    get(:mapping, :params => {:id => import.to_param})

    # 'user' field should be available because User#2 has both
    # 'import_time_entries' and 'log_time_for_other_users' permissions
    assert_select 'select[name=?]', 'import_settings[mapping][user]' do
      # Current user should be the default value if there is not auto map present
      assert_select 'option[value="value:2"][selected]', :text => User.find(2).name
      assert_select 'option[value="value:3"]', :text => User.find(3).name
    end
  end

  def test_get_mapping_time_entry_for_user_without_log_time_for_other_users_permission
    import = generate_time_entry_import
    import.settings = {'separator' => ";", 'wrapper' => '"', 'encoding' => "ISO-8859-1"}
    import.save!

    get(:mapping, :params => {:id => import.to_param})

    assert_response :success

    assert_select 'select[name=?]', 'import_settings[mapping][user_id]', 0
  end

  def test_get_run
    import = generate_import_with_mapping

    get(:run, :params => {:id => import})
    assert_response :success
    assert_select '#import-progress'
  end

  def test_post_run_should_import_the_file
    import = generate_import_with_mapping

    assert_difference 'Issue.count', 3 do
      post(:run, :params => {:id => import})
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
      post(:run, :params => {:id => import})
      assert_redirected_to "/imports/#{import.to_param}/run"
    end

    assert_difference 'Issue.count', 1 do
      post(:run, :params => {:id => import})
      assert_redirected_to "/imports/#{import.to_param}"
    end

    issues = Issue.order(:id => :desc).limit(3).to_a
    assert_equal ["Child of existing issue", "Child 1", "First"], issues.map(&:subject)
  end

  def test_post_run_with_notifications
    import = generate_import

    post(
      :settings,
      :params => {
        :id => import,
        :import_settings => {
          :separator => ';',
          :wrapper => '"',
          :encoding => 'ISO-8859-1',
          :notifications => '1',
          :mapping => {
            :project_id => '1',
            :tracker => '13',
            :subject => '1',
            :assigned_to => '11',
          }
        }
      }
    )
    ActionMailer::Base.deliveries.clear
    assert_difference 'Issue.count', 3 do
      post(:run, :params => {:id => import,})
      assert_response :found
    end
    actual_email_count = ActionMailer::Base.deliveries.size
    assert_not_equal 0, actual_email_count

    import.reload
    issue_ids = import.items.collect(&:obj_id)
    expected_email_count =
      Issue.where(:id => issue_ids).inject(0) do |sum, issue|
        sum + (issue.notified_users | issue.notified_watchers).size
      end
    assert_equal expected_email_count, actual_email_count
  end

  def test_show_without_errors
    import = generate_import_with_mapping
    import.run
    assert_equal 0, import.unsaved_items.count

    get(:show, :params => {:id => import.to_param})
    assert_response :success

    assert_select 'ul#saved-items'
    assert_select 'ul#saved-items li', import.saved_items.count
    assert_select 'table#unsaved-items', 0
  end

  def test_show_with_errors_should_show_unsaved_items
    import = generate_import_with_mapping
    import.mapping['subject'] = 20
    import.run
    assert_not_equal 0, import.unsaved_items.count

    get(:show, :params => {:id => import.to_param})
    assert_response :success

    assert_select 'table#unsaved-items'
    assert_select 'table#unsaved-items tbody tr', import.unsaved_items.count
  end
end
