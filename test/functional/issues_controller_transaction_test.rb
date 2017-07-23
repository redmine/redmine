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

require File.expand_path('../../test_helper', __FILE__)
require 'issues_controller'

class IssuesControllerTransactionTest < Redmine::ControllerTest
  tests IssuesController
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :issues,
           :issue_statuses,
           :versions,
           :trackers,
           :projects_trackers,
           :issue_categories,
           :enabled_modules,
           :enumerations,
           :attachments,
           :workflows,
           :custom_fields,
           :custom_values,
           :custom_fields_projects,
           :custom_fields_trackers,
           :time_entries,
           :journals,
           :journal_details,
           :queries

  self.use_transactional_tests = false

  def setup
    User.current = nil
  end

  def test_update_stale_issue_should_not_update_the_issue
    issue = Issue.find(2)
    @request.session[:user_id] = 2

    assert_no_difference 'Journal.count' do
      assert_no_difference 'TimeEntry.count' do
        put :update, :params => {
            :id => issue.id,
            :issue => {
              :fixed_version_id => 4,
              :notes => 'My notes',
              :lock_version => (issue.lock_version - 1)
              
            },  
            :time_entry => {
              :hours => '2.5',
              :comments => '',
              :activity_id => TimeEntryActivity.first.id 
            }
          }
      end
    end

    assert_response :success

    assert_select 'div.conflict'
    assert_select 'input[name=?][value=?]', 'conflict_resolution', 'overwrite'
    assert_select 'input[name=?][value=?]', 'conflict_resolution', 'add_notes'
    assert_select 'label' do
      assert_select 'input[name=?][value=?]', 'conflict_resolution', 'cancel'
      assert_select 'a[href="/issues/2"]'
    end
  end

  def test_update_stale_issue_should_save_attachments
    set_tmp_attachments_directory
    issue = Issue.find(2)
    @request.session[:user_id] = 2

    assert_no_difference 'Journal.count' do
      assert_no_difference 'TimeEntry.count' do
        assert_difference 'Attachment.count' do
          put :update, :params => {
              :id => issue.id,
              :issue => {
                :fixed_version_id => 4,
                :notes => 'My notes',
                :lock_version => (issue.lock_version - 1)
                
              },  
              :attachments => {
                '1' => {
                'file' => uploaded_test_file('testfile.txt', 'text/plain')}    
              },  
              :time_entry => {
                :hours => '2.5',
                :comments => '',
                :activity_id => TimeEntryActivity.first.id 
              }
            }
        end
      end
    end

    assert_response :success

    attachment = Attachment.order('id DESC').first
    assert_select 'input[name=?][value=?]', 'attachments[p0][token]', attachment.token
    assert_select 'input[name=?][value=?]', 'attachments[p0][filename]', 'testfile.txt'
  end

  def test_update_stale_issue_without_notes_should_not_show_add_notes_option
    issue = Issue.find(2)
    @request.session[:user_id] = 2

    put :update, :params => {
        :id => issue.id,
        :issue => {
          :fixed_version_id => 4,
          :notes => '',
          :lock_version => (issue.lock_version - 1)
          
        }
      }
    assert_response :success

    assert_select 'div.conflict'
    assert_select 'input[name=conflict_resolution][value=overwrite]'
    assert_select 'input[name=conflict_resolution][value=add_notes]', 0
    assert_select 'input[name=conflict_resolution][value=cancel]'
  end

  def test_update_stale_issue_should_show_conflicting_journals
    @request.session[:user_id] = 2

    put :update, :params => {
        :id => 1,
        :issue => {
          :fixed_version_id => 4,
          :notes => '',
          :lock_version => 2
          
        },  
        :last_journal_id => 1
      }
    assert_response :success

    assert_select '.conflict-journal', 1
    assert_select 'div.conflict', :text => /Some notes with Redmine links/
  end

  def test_update_stale_issue_without_previous_journal_should_show_all_journals
    @request.session[:user_id] = 2

    put :update, :params => {
        :id => 1,
        :issue => {
          :fixed_version_id => 4,
          :notes => '',
          :lock_version => 2
          
        },  
        :last_journal_id => ''
      }
    assert_response :success

    assert_select '.conflict-journal', 2
    assert_select 'div.conflict', :text => /Some notes with Redmine links/
    assert_select 'div.conflict', :text => /Journal notes/
  end

  def test_update_stale_issue_should_show_private_journals_with_permission_only
    journal = Journal.create!(:journalized => Issue.find(1), :notes => 'Privates notes', :private_notes => true, :user_id => 1)

    @request.session[:user_id] = 2
    put :update, :params => {
        :id => 1,
        :issue => {
          :fixed_version_id => 4,
          :lock_version => 2
        },  
        :last_journal_id => ''
      }
    assert_response :success
    assert_select '.conflict-journal', :text => /Privates notes/

    Role.find(1).remove_permission! :view_private_notes
    put :update, :params => {
        :id => 1,
        :issue => {
          :fixed_version_id => 4,
          :lock_version => 2
        },  
        :last_journal_id => ''
      }
    assert_response :success
    assert_select '.conflict-journal', :text => /Privates notes/, :count => 0
  end

  def test_update_stale_issue_with_overwrite_conflict_resolution_should_update
    @request.session[:user_id] = 2

    assert_difference 'Journal.count' do
      put :update, :params => {
          :id => 1,
          :issue => {
            :fixed_version_id => 4,
            :notes => 'overwrite_conflict_resolution',
            :lock_version => 2
            
          },  
          :conflict_resolution => 'overwrite'
        }
    end

    assert_response 302
    issue = Issue.find(1)
    assert_equal 4, issue.fixed_version_id
    journal = Journal.order('id DESC').first
    assert_equal 'overwrite_conflict_resolution', journal.notes
    assert journal.details.any?
  end

  def test_update_stale_issue_with_add_notes_conflict_resolution_should_update
    @request.session[:user_id] = 2

    assert_difference 'Journal.count' do
      put :update, :params => {
          :id => 1,
          :issue => {
            :fixed_version_id => 4,
            :notes => 'add_notes_conflict_resolution',
            :lock_version => 2
            
          },  
          :conflict_resolution => 'add_notes'
        }
    end

    assert_response 302
    issue = Issue.find(1)
    assert_nil issue.fixed_version_id
    journal = Journal.order('id DESC').first
    assert_equal 'add_notes_conflict_resolution', journal.notes
    assert_equal false, journal.private_notes
    assert journal.details.empty?
  end

  def test_update_stale_issue_with_add_notes_conflict_resolution_should_preserve_private_notes
    @request.session[:user_id] = 2

    journal = new_record(Journal) do
      put :update, :params => {
          :id => 1,
          :issue => {
            :fixed_version_id => 4,
            :notes => 'add_privates_notes_conflict_resolution',
            :private_notes => '1',
            :lock_version => 2
            
          },  
          :conflict_resolution => 'add_notes'
        }
    end

    assert_response 302
    assert_equal 'add_privates_notes_conflict_resolution', journal.notes
    assert_equal true, journal.private_notes
    assert journal.details.empty?
  end

  def test_update_stale_issue_with_cancel_conflict_resolution_should_redirect_without_updating
    @request.session[:user_id] = 2

    assert_no_difference 'Journal.count' do
      put :update, :params => {
          :id => 1,
          :issue => {
            :fixed_version_id => 4,
            :notes => 'add_notes_conflict_resolution',
            :lock_version => 2
            
          },  
          :conflict_resolution => 'cancel'
        }
    end

    assert_redirected_to '/issues/1'
    issue = Issue.find(1)
    assert_nil issue.fixed_version_id
  end

  def test_put_update_with_spent_time_and_failure_should_not_add_spent_time
    @request.session[:user_id] = 2

    assert_no_difference('TimeEntry.count') do
      put :update, :params => {
          :id => 1,
          :issue => {
            :subject => '' 
          },  
          :time_entry => {
            :hours => '2.5',
            :comments => 'should not be added',
            :activity_id => TimeEntryActivity.first.id 
          }
        }
      assert_response :success
    end

    assert_select 'input[name=?][value=?]', 'time_entry[hours]', '2.50'
    assert_select 'input[name=?][value=?]', 'time_entry[comments]', 'should not be added'
    assert_select 'select[name=?]', 'time_entry[activity_id]' do
      assert_select 'option[value=?][selected=selected]', TimeEntryActivity.first.id.to_s
    end
  end

  def test_index_should_rescue_invalid_sql_query
    IssueQuery.any_instance.stubs(:statement).returns("INVALID STATEMENT")

    get :index
    assert_response 500
    assert_select 'p', :text => /An error occurred/
    assert_nil session[:query]
    assert_nil session[:issues_index_sort]
  end
end
