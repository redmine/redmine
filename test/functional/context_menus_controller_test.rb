# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
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

class ContextMenusControllerTest < ActionController::TestCase
  fixtures :projects,
           :trackers,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :workflows,
           :journals, :journal_details,
           :versions,
           :issues, :issue_statuses, :issue_categories,
           :users,
           :enumerations,
           :time_entries

  def test_context_menu_one_issue
    @request.session[:user_id] = 2
    get :issues, :ids => [1]
    assert_response :success
    assert_template 'context_menu'
    assert_tag :tag => 'a', :content => 'Edit',
                            :attributes => { :href => '/issues/1/edit',
                                             :class => 'icon-edit' }
    assert_tag :tag => 'a', :content => 'Closed',
                            :attributes => { :href => '/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bstatus_id%5D=5',
                                             :class => '' }
    assert_tag :tag => 'a', :content => 'Immediate',
                            :attributes => { :href => '/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bpriority_id%5D=8',
                                             :class => '' }
    assert_no_tag :tag => 'a', :content => 'Inactive Priority'
    # Versions
    assert_tag :tag => 'a', :content => '2.0',
                            :attributes => { :href => '/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bfixed_version_id%5D=3',
                                             :class => '' }
    assert_tag :tag => 'a', :content => 'eCookbook Subproject 1 - 2.0',
                            :attributes => { :href => '/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bfixed_version_id%5D=4',
                                             :class => '' }

    assert_tag :tag => 'a', :content => 'Dave Lopper',
                            :attributes => { :href => '/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bassigned_to_id%5D=3',
                                             :class => '' }
    assert_tag :tag => 'a', :content => 'Copy',
                            :attributes => { :href => '/projects/ecookbook/issues/1/copy',
                                             :class => 'icon-copy' }
    assert_no_tag :tag => 'a', :content => 'Move'
    assert_tag :tag => 'a', :content => 'Delete',
                            :attributes => { :href => '/issues?ids%5B%5D=1',
                                             :class => 'icon-del' }
  end

  def test_context_menu_one_issue_by_anonymous
    get :issues, :ids => [1]
    assert_response :success
    assert_template 'context_menu'
    assert_tag :tag => 'a', :content => 'Delete',
                            :attributes => { :href => '#',
                                             :class => 'icon-del disabled' }
  end

  def test_context_menu_multiple_issues_of_same_project
    @request.session[:user_id] = 2
    get :issues, :ids => [1, 2]
    assert_response :success
    assert_template 'context_menu'
    assert_not_nil assigns(:issues)
    assert_equal [1, 2], assigns(:issues).map(&:id).sort

    ids = assigns(:issues).map(&:id).sort.map {|i| "ids%5B%5D=#{i}"}.join('&amp;')
    assert_tag :tag => 'a', :content => 'Edit',
                            :attributes => { :href => "/issues/bulk_edit?#{ids}",
                                             :class => 'icon-edit' }
    assert_tag :tag => 'a', :content => 'Closed',
                            :attributes => { :href => "/issues/bulk_update?#{ids}&amp;issue%5Bstatus_id%5D=5",
                                             :class => '' }
    assert_tag :tag => 'a', :content => 'Immediate',
                            :attributes => { :href => "/issues/bulk_update?#{ids}&amp;issue%5Bpriority_id%5D=8",
                                             :class => '' }
    assert_tag :tag => 'a', :content => 'Dave Lopper',
                            :attributes => { :href => "/issues/bulk_update?#{ids}&amp;issue%5Bassigned_to_id%5D=3",
                                             :class => '' }
    assert_tag :tag => 'a', :content => 'Copy',
                            :attributes => { :href => "/issues/bulk_edit?copy=1&amp;#{ids}",
                                             :class => 'icon-copy' }
    assert_no_tag :tag => 'a', :content => 'Move'
    assert_tag :tag => 'a', :content => 'Delete',
                            :attributes => { :href => "/issues?#{ids}",
                                             :class => 'icon-del' }
  end

  def test_context_menu_multiple_issues_of_different_projects
    @request.session[:user_id] = 2
    get :issues, :ids => [1, 2, 6]
    assert_response :success
    assert_template 'context_menu'
    assert_not_nil assigns(:issues)
    assert_equal [1, 2, 6], assigns(:issues).map(&:id).sort

    ids = assigns(:issues).map(&:id).sort.map {|i| "ids%5B%5D=#{i}"}.join('&amp;')
    assert_tag :tag => 'a', :content => 'Edit',
                            :attributes => { :href => "/issues/bulk_edit?#{ids}",
                                             :class => 'icon-edit' }
    assert_tag :tag => 'a', :content => 'Closed',
                            :attributes => { :href => "/issues/bulk_update?#{ids}&amp;issue%5Bstatus_id%5D=5",
                                             :class => '' }
    assert_tag :tag => 'a', :content => 'Immediate',
                            :attributes => { :href => "/issues/bulk_update?#{ids}&amp;issue%5Bpriority_id%5D=8",
                                             :class => '' }
    assert_tag :tag => 'a', :content => 'John Smith',
                            :attributes => { :href => "/issues/bulk_update?#{ids}&amp;issue%5Bassigned_to_id%5D=2",
                                             :class => '' }
    assert_tag :tag => 'a', :content => 'Delete',
                            :attributes => { :href => "/issues?#{ids}",
                                             :class => 'icon-del' }
  end

  def test_context_menu_should_include_list_custom_fields
    field = IssueCustomField.create!(:name => 'List', :field_format => 'list',
      :possible_values => ['Foo', 'Bar'], :is_for_all => true, :tracker_ids => [1, 2, 3])
    @request.session[:user_id] = 2
    get :issues, :ids => [1]

    assert_tag 'a',
      :content => 'List',
      :attributes => {:href => '#'},
      :sibling => {:tag => 'ul', :children => {:count => 3}}

    assert_tag 'a',
      :content => 'Foo',
      :attributes => {:href => "/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bcustom_field_values%5D%5B#{field.id}%5D=Foo"}
    assert_tag 'a',
      :content => 'none',
      :attributes => {:href => "/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bcustom_field_values%5D%5B#{field.id}%5D="}
  end

  def test_context_menu_should_not_include_null_value_for_required_custom_fields
    field = IssueCustomField.create!(:name => 'List', :is_required => true, :field_format => 'list',
      :possible_values => ['Foo', 'Bar'], :is_for_all => true, :tracker_ids => [1, 2, 3])
    @request.session[:user_id] = 2
    get :issues, :ids => [1, 2]

    assert_tag 'a',
      :content => 'List',
      :attributes => {:href => '#'},
      :sibling => {:tag => 'ul', :children => {:count => 2}}
  end

  def test_context_menu_on_single_issue_should_select_current_custom_field_value
    field = IssueCustomField.create!(:name => 'List', :field_format => 'list',
      :possible_values => ['Foo', 'Bar'], :is_for_all => true, :tracker_ids => [1, 2, 3])
    issue = Issue.find(1)
    issue.custom_field_values = {field.id => 'Bar'}
    issue.save!
    @request.session[:user_id] = 2
    get :issues, :ids => [1]

    assert_tag 'a',
      :content => 'List',
      :attributes => {:href => '#'},
      :sibling => {:tag => 'ul', :children => {:count => 3}}
    assert_tag 'a',
      :content => 'Bar',
      :attributes => {:class => /icon-checked/}
  end

  def test_context_menu_should_include_bool_custom_fields
    field = IssueCustomField.create!(:name => 'Bool', :field_format => 'bool',
      :is_for_all => true, :tracker_ids => [1, 2, 3])
    @request.session[:user_id] = 2
    get :issues, :ids => [1]

    assert_tag 'a',
      :content => 'Bool',
      :attributes => {:href => '#'},
      :sibling => {:tag => 'ul', :children => {:count => 3}}

    assert_tag 'a',
      :content => 'Yes',
      :attributes => {:href => "/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bcustom_field_values%5D%5B#{field.id}%5D=1"}
  end

  def test_context_menu_should_include_user_custom_fields
    field = IssueCustomField.create!(:name => 'User', :field_format => 'user',
      :is_for_all => true, :tracker_ids => [1, 2, 3])
    @request.session[:user_id] = 2
    get :issues, :ids => [1]

    assert_tag 'a',
      :content => 'User',
      :attributes => {:href => '#'},
      :sibling => {:tag => 'ul', :children => {:count => Project.find(1).members.count + 1}}

    assert_tag 'a',
      :content => 'John Smith',
      :attributes => {:href => "/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bcustom_field_values%5D%5B#{field.id}%5D=2"}
  end

  def test_context_menu_should_include_version_custom_fields
    field = IssueCustomField.create!(:name => 'Version', :field_format => 'version', :is_for_all => true, :tracker_ids => [1, 2, 3])
    @request.session[:user_id] = 2
    get :issues, :ids => [1]

    assert_tag 'a',
      :content => 'Version',
      :attributes => {:href => '#'},
      :sibling => {:tag => 'ul', :children => {:count => Project.find(1).shared_versions.count + 1}}

    assert_tag 'a',
      :content => '2.0',
      :attributes => {:href => "/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bcustom_field_values%5D%5B#{field.id}%5D=3"}
  end

  def test_context_menu_by_assignable_user_should_include_assigned_to_me_link
    @request.session[:user_id] = 2
    get :issues, :ids => [1]
    assert_response :success
    assert_template 'context_menu'

    assert_tag :tag => 'a', :content => / me /,
                            :attributes => { :href => '/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bassigned_to_id%5D=2',
                                             :class => '' }
  end

  def test_context_menu_should_propose_shared_versions_for_issues_from_different_projects
    @request.session[:user_id] = 2
    version = Version.create!(:name => 'Shared', :sharing => 'system', :project_id => 1)

    get :issues, :ids => [1, 4]
    assert_response :success
    assert_template 'context_menu'

    assert_include version, assigns(:versions)
    assert_tag :tag => 'a', :content => 'eCookbook - Shared'
  end

  def test_context_menu_issue_visibility
    get :issues, :ids => [1, 4]
    assert_response :success
    assert_template 'context_menu'
    assert_equal [1], assigns(:issues).collect(&:id)
  end
  
  def test_time_entries_context_menu
    @request.session[:user_id] = 2
    get :time_entries, :ids => [1, 2]
    assert_response :success
    assert_template 'time_entries'
    assert_tag 'a', :content => 'Edit'
    assert_no_tag 'a', :content => 'Edit', :attributes => {:class => /disabled/}
  end
  
  def test_time_entries_context_menu_without_edit_permission
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').remove_permission! :edit_time_entries
    
    get :time_entries, :ids => [1, 2]
    assert_response :success
    assert_template 'time_entries'
    assert_tag 'a', :content => 'Edit', :attributes => {:class => /disabled/}
  end
end
