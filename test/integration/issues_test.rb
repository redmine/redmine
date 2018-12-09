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

class IssuesTest < Redmine::IntegrationTest
  fixtures :projects,
           :users, :email_addresses,
           :roles,
           :members,
           :member_roles,
           :trackers,
           :projects_trackers,
           :enabled_modules,
           :issue_statuses,
           :issues,
           :enumerations,
           :custom_fields,
           :custom_values,
           :custom_fields_trackers,
           :attachments

  # create an issue
  def test_add_issue
    log_user('jsmith', 'jsmith')

    get '/projects/ecookbook/issues/new'
    assert_response :success

    issue = new_record(Issue) do
      post '/projects/ecookbook/issues', :params => {
          :issue => {
            :tracker_id => "1",
            :start_date => "2006-12-26",
            :priority_id => "4",
            :subject => "new test issue",
            :category_id => "",
            :description => "new issue",
            :done_ratio => "0",
            :due_date => "",
            :assigned_to_id => "",
            :custom_field_values => {'2' => 'Value for field 2'}
          }
        }
    end
    # check redirection
    assert_redirected_to :controller => 'issues', :action => 'show', :id => issue
    follow_redirect!

    # check issue attributes
    assert_equal 'jsmith', issue.author.login
    assert_equal 1, issue.project.id
    assert_equal 1, issue.status.id
  end

  def test_create_issue_by_anonymous_without_permission_should_fail
    Role.anonymous.remove_permission! :add_issues

    assert_no_difference 'Issue.count' do
      post '/projects/1/issues', :params => {
          :issue => {
            :tracker_id => "1",
            :subject => "new test issue"
          }
        }
    end
    assert_response 302
  end

  def test_create_issue_by_anonymous_with_custom_permission_should_succeed
    Role.anonymous.remove_permission! :add_issues
    Member.create!(:project_id => 1, :principal => Group.anonymous, :role_ids => [3])

    issue = new_record(Issue) do
      post '/projects/1/issues', :params => {
          :issue => {
            :tracker_id => "1",
            :subject => "new test issue"
          }
        }
      assert_response 302
    end
    assert_equal User.anonymous, issue.author
  end

  # add then remove 2 attachments to an issue
  def test_issue_attachments
    log_user('jsmith', 'jsmith')
    set_tmp_attachments_directory

    attachment = new_record(Attachment) do
      put '/issues/1', :params => {
          :issue => {:notes => 'Some notes'},
          :attachments => {'1' => {'file' => uploaded_test_file('testfile.txt', 'text/plain'), 'description' => 'This is an attachment'}}
        }
      assert_redirected_to "/issues/1"
    end

    assert_equal Issue.find(1), attachment.container
    assert_equal 'testfile.txt', attachment.filename
    assert_equal 'This is an attachment', attachment.description
    # verify the size of the attachment stored in db
    #assert_equal file_data_1.length, attachment.filesize
    # verify that the attachment was written to disk
    assert File.exist?(attachment.diskfile)

    # remove the attachments
    Issue.find(1).attachments.each(&:destroy)
    assert_equal 0, Issue.find(1).attachments.length
  end

  def test_next_and_previous_links_should_be_displayed_after_query_grouped_and_sorted_by_version
    with_settings :default_language => 'en' do
      get '/projects/ecookbook/issues?set_filter=1&group_by=fixed_version&sort=priority:desc,fixed_version,id'
      assert_response :success
      assert_select 'td.id', :text => '5'
  
      get '/issues/5'
      assert_response :success
      assert_select '.next-prev-links .position', :text => '5 of 6'
    end
  end

  def test_next_and_previous_links_should_be_displayed_after_filter
    with_settings :default_language => 'en' do
      get '/projects/ecookbook/issues?set_filter=1&tracker_id=1'
      assert_response :success
      assert_select 'td.id', :text => '5'
  
      get '/issues/5'
      assert_response :success
      assert_select '.next-prev-links .position', :text => '3 of 5'
      assert_select '.next-prev-links .position a[href^=?]', '/projects/ecookbook/issues?'
    end
  end

  def test_next_and_previous_links_should_be_displayed_after_saved_query
    query = IssueQuery.create!(:name => 'Calendar Query',
      :visibility => IssueQuery::VISIBILITY_PUBLIC,
      :filters => {'tracker_id' => {:operator => '=', :values => ['1']}}
    )

    with_settings :default_language => 'en' do
      get "/projects/ecookbook/issues?set_filter=1&query_id=#{query.id}"
      assert_response :success
      assert_select 'td.id', :text => '5'
  
      get '/issues/5'
      assert_response :success
      assert_select '.next-prev-links .position', :text => '6 of 8'
    end
  end

  def test_other_formats_links_on_index
    get '/projects/ecookbook/issues'

    %w(Atom PDF CSV).each do |format|
      assert_select 'a[rel=nofollow][href=?]', "/projects/ecookbook/issues.#{format.downcase}", :text => format
    end
  end

  def test_other_formats_links_on_index_without_project_id_in_url
    get '/issues', :params => {
        :project_id => 'ecookbook'
      }

    %w(Atom PDF CSV).each do |format|
      assert_select 'a[rel=nofollow][href=?]', "/issues.#{format.downcase}?project_id=ecookbook", :text => format
    end
  end

  def test_pagination_links_on_index
    with_settings :per_page_options => '2' do
      get '/projects/ecookbook/issues'

      assert_select 'a[href=?]', '/projects/ecookbook/issues?page=2', :text => '2'
    end
  end

  def test_pagination_links_should_preserve_query_parameters
    with_settings :per_page_options => '2' do
      get '/projects/ecookbook/issues?foo=bar'

      assert_select 'a[href=?]', '/projects/ecookbook/issues?foo=bar&page=2', :text => '2'
    end
  end

  def test_pagination_links_should_not_use_params_as_url_options
    with_settings :per_page_options => '2' do
      get '/projects/ecookbook/issues?host=foo'

      assert_select 'a[href=?]', '/projects/ecookbook/issues?host=foo&page=2', :text => '2'
    end
  end

  def test_sort_links_on_index
    get '/projects/ecookbook/issues'

    assert_select 'a[href=?]', '/projects/ecookbook/issues?sort=subject%2Cid%3Adesc', :text => 'Subject'
  end

  def test_sort_links_should_preserve_query_parameters
    get '/projects/ecookbook/issues?foo=bar'

    assert_select 'a[href=?]', '/projects/ecookbook/issues?foo=bar&sort=subject%2Cid%3Adesc', :text => 'Subject'
  end

  def test_sort_links_should_not_use_params_as_url_options
    get '/projects/ecookbook/issues?host=foo'

    assert_select 'a[href=?]', '/projects/ecookbook/issues?host=foo&sort=subject%2Cid%3Adesc', :text => 'Subject'
  end

  def test_issue_with_user_custom_field
    @field = IssueCustomField.create!(:name => 'Tester', :field_format => 'user', :is_for_all => true, :trackers => Tracker.all)
    Role.anonymous.add_permission! :add_issues, :edit_issues
    users = Project.find(1).users.sort
    tester = users.first

    # Issue form
    get '/projects/ecookbook/issues/new'
    assert_response :success
    assert_select 'select[name=?]', "issue[custom_field_values][#{@field.id}]" do
      assert_select 'option', users.size + 1 # +1 for blank value
      assert_select 'option[value=?]', tester.id.to_s, :text => tester.name
    end

    # Create issue
    issue = new_record(Issue) do
      post '/projects/ecookbook/issues', :params => {
          :issue => {
            :tracker_id => '1',
            :priority_id => '4',
            :subject => 'Issue with user custom field',
            :custom_field_values => {@field.id.to_s => users.first.id.to_s}
          }
        }
      assert_response 302
    end

    # Issue view
    follow_redirect!
    assert_select ".cf_#{@field.id}" do
      assert_select '.label', :text => 'Tester:'
      assert_select '.value', :text => tester.name
    end
    assert_select 'select[name=?]', "issue[custom_field_values][#{@field.id}]" do
      assert_select 'option', users.size + 1 # +1 for blank value
      assert_select 'option[value=?][selected=selected]', tester.id.to_s, :text => tester.name
    end

    new_tester = users[1]
    with_settings :default_language => 'en' do
      # Update issue
      assert_difference 'Journal.count' do
        put "/issues/#{issue.id}", :params => {
            :issue => {
              :notes => 'Updating custom field',
              :custom_field_values => {@field.id.to_s => new_tester.id.to_s}
            }
          }
        assert_redirected_to "/issues/#{issue.id}"
      end
      # Issue view
      follow_redirect!
      assert_select 'ul.details li', :text => "Tester changed from #{tester} to #{new_tester}"
    end
  end

  def test_update_using_invalid_http_verbs
    log_user('jsmith', 'jsmith')
    subject = 'Updated by an invalid http verb'

    get '/issues/update/1', :params => {:issue => {:subject => subject}}
    assert_response 404
    assert_not_equal subject, Issue.find(1).subject

    post '/issues/1', :params => {:issue => {:subject => subject}}
    assert_response 404
    assert_not_equal subject, Issue.find(1).subject
  end

  def test_get_watch_should_be_invalid
    log_user('jsmith', 'jsmith')

    assert_no_difference 'Watcher.count' do
      get '/watchers/watch?object_type=issue&object_id=1'
      assert_response 404
    end
  end
end
