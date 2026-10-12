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

class MembersControllerTest < Redmine::ControllerTest
  def setup
    User.current = nil
    @request.session[:user_id] = 2
  end

  def test_index_with_csv_format_should_export_csv
    project = Project.find(5)
    get(
      :index,
      params: {
        project_id: project.id,
        format: 'csv'
      }
    )
    assert_response :success
    assert_equal 'text/csv; header=present', response.media_type

    lines = response.body.chomp.split("\n")
    # Number of lines
    assert_equal project.memberships.sum{|m| m.roles.count } + 1, lines.size
    # Header
    assert_equal "User or Group,Type,Role,Project", lines.first
    # Details
    to_test = [
      'John Smith,User,Manager,Private child of eCookbook',
      'A Team,Group,Manager,Private child of eCookbook',
      'A Team,Group,Developer,Private child of eCookbook',
      'User Misc,User,Manager,Private child of eCookbook',
      'User Misc,User,Developer,Private child of eCookbook',
      'Redmine Admin,User,Manager,Private child of eCookbook'
    ]
    to_test.each do |expected|
      assert_includes lines, expected
    end
  end

  def test_new
    get(:new, :params => {:project_id => 1})
    assert_response :success
  end

  def test_new_should_propose_managed_roles_only
    role = Role.find(1)
    role.update! :all_roles_managed => false
    role.managed_roles = Role.where(:id => [2, 3]).to_a

    get(:new, :params => {:project_id => 1})
    assert_response :success
    assert_select 'div.roles-selection' do
      assert_select 'label', :text => 'Manager', :count => 0
      assert_select 'label', :text => 'Developer'
      assert_select 'label', :text => 'Reporter'
    end
  end

  def test_xhr_new
    get(:new, :params => {:project_id => 1}, :xhr => true)
    assert_response :success
    assert_equal 'text/javascript', response.media_type
  end

  def test_create
    assert_difference 'Member.count' do
      post(
        :create,
        :params => {
          :project_id => 1,
          :membership => {
            :role_ids => [1],
            :user_id => 7
          }
        }
      )
    end
    assert_redirected_to '/projects/ecookbook/settings/members'
    assert User.find(7).member_of?(Project.find(1))
  end

  def test_create_multiple
    assert_difference 'Member.count', 3 do
      post(
        :create,
        :params => {
          :project_id => 1,
          :membership => {
            :role_ids => [1],
            :user_ids => [7, 8, 9]
          }
        }
      )
    end
    assert_redirected_to '/projects/ecookbook/settings/members'
    assert User.find(7).member_of?(Project.find(1))
  end

  def test_create_should_ignore_unmanaged_roles
    role = Role.find(1)
    role.update! :all_roles_managed => false
    role.managed_roles = Role.where(:id => [2, 3]).to_a

    assert_difference 'Member.count' do
      post(
        :create,
        :params => {
          :project_id => 1,
          :membership => {
            :role_ids => [1, 2],
            :user_id => 7
          }
        }
      )
    end
    member = Member.order(:id => :desc).first
    assert_equal [2], member.role_ids
  end

  def test_create_should_be_allowed_for_admin_without_role
    User.find(1).members.delete_all
    @request.session[:user_id] = 1

    assert_difference 'Member.count' do
      post(
        :create,
        :params => {
          :project_id => 1,
          :membership => {
            :role_ids => [1, 2],
            :user_id => 7
          }
        }
      )
    end
    member = Member.order(:id => :desc).first
    assert_equal [1, 2], member.role_ids
  end

  def test_xhr_create
    assert_difference 'Member.count', 3 do
      post(
        :create,
        :params => {
          :project_id => 1,
          :membership => {
            :role_ids => [1],
            :user_ids => [7, 8, 9]
          }
        },
        :xhr => true
      )
      assert_response :success
      assert_equal 'text/javascript', response.media_type
    end
    assert User.find(7).member_of?(Project.find(1))
    assert User.find(8).member_of?(Project.find(1))
    assert User.find(9).member_of?(Project.find(1))
    assert_include 'tab-content-members', response.body
  end

  def test_xhr_create_with_failure
    assert_no_difference 'Member.count' do
      post(
        :create,
        :params => {
          :project_id => 1,
          :membership => {
            :role_ids => [],
            :user_ids => [7, 8, 9]
          }
        },
        :xhr => true
      )
      assert_response :success
      assert_equal 'text/javascript', response.media_type
    end
    assert_match /alert/, response.body, "Alert message not sent"
  end

  def test_edit
    get(:edit, :params => {:id => 2})
    assert_response :success
    assert_select 'input[name=?][value=?][checked=checked]', 'membership[role_ids][]', '2'
  end

  def test_xhr_edit
    get(:edit, :params => {:id => 2}, :xhr => true)
    assert_response :success
  end

  def test_update
    assert_no_difference 'Member.count' do
      put(
        :update,
        :params => {
          :id => 2,
          :membership => {
            :role_ids => [1],
            :user_id => 3
          }
        }
      )
    end
    assert_redirected_to '/projects/ecookbook/settings/members'
  end

  def test_update_xhr_should_keep_members_tab_in_pagination_links
    project = Project.find(1)
    26.times { User.add_to_project(User.generate!, project) }
    @request.session[:user_id] = 2
    with_settings :per_page_options => '25,50,100' do
      put(
        :update,
        :params => {
          :id => 2,
          :membership => {:role_ids => [1]}
        },
        :xhr => true
      )
    end
    assert_response :success
    assert_match %r{settings/members\?members_page=}, response.body
  end

  def test_edit_xhr_should_keep_current_page_in_form_action
    @request.session[:user_id] = 2
    get(:edit, :params => {:id => 2, :members_page => 2}, :xhr => true)
    assert_response :success
    assert_match %r{/memberships/2\?members_page=2}, response.body
  end

  def test_new_xhr_should_keep_current_page_in_form_action
    @request.session[:user_id] = 2
    get(:new, :params => {:project_id => 1, :members_page => 2}, :xhr => true)
    assert_response :success
    assert_match %r{/projects/ecookbook/memberships\?members_page=2}, response.body
  end

  def test_destroy_xhr_should_keep_members_tab_in_pagination_links
    project = Project.find(1)
    26.times { User.add_to_project(User.generate!, project) }
    @request.session[:user_id] = 2
    with_settings :per_page_options => '25,50,100' do
      delete(
        :destroy,
        :params => {
          :id => 2,
          :members_page => 2
        },
        :xhr => true
      )
    end
    assert_response :success
    assert_match %r{settings/members\?members_page=}, response.body
  end

  def test_edit_xhr_should_keep_current_filters_in_form_action
    @request.session[:user_id] = 2
    get(:edit, :params => {:id => 2, :member_name => 'Smith', :member_role_id => 1}, :xhr => true)
    assert_response :success
    assert_match %r{/memberships/2\?member_name=Smith&amp;member_role_id=1}, response.body
  end

  def test_new_xhr_should_keep_current_filters_in_form_action
    @request.session[:user_id] = 2
    get(:new, :params => {:project_id => 1, :member_name => 'Smith', :member_role_id => 1}, :xhr => true)
    assert_response :success
    assert_match %r{/projects/ecookbook/memberships\?member_name=Smith&amp;member_role_id=1}, response.body
  end

  def test_update_xhr_should_keep_the_members_list_filtered
    @request.session[:user_id] = 2
    put(
      :update,
      :params => {
        :id => 2,
        :membership => {:role_ids => [2]},
        :member_role_id => 1
      },
      :xhr => true
    )
    assert_response :success
    # The updated member does not match the filter anymore, but the list
    # must still be filtered by role 1
    assert_match %r{/memberships/1\?member_role_id=1}, response.body
    assert_no_match %r{member-4}, response.body
  end

  def test_destroy_xhr_should_keep_the_members_list_filtered
    @request.session[:user_id] = 2
    assert_difference 'Member.count', -1 do
      delete(:destroy, :params => {:id => 2, :member_name => 'Smith'}, :xhr => true)
    end
    assert_response :success
    assert_match %r{/memberships/1\?member_name=Smith}, response.body
    assert_no_match %r{member-4}, response.body
  end

  def test_destroy_should_redirect_to_the_filtered_members_list
    @request.session[:user_id] = 2
    assert_difference 'Member.count', -1 do
      delete(:destroy, :params => {:id => 2, :member_name => 'Smith', :member_role_id => 1})
    end
    assert_redirected_to '/projects/ecookbook/settings/members?member_name=Smith&member_role_id=1'
  end

  def test_update_locked_member_should_be_allowed
    User.find(3).lock!

    put(
      :update,
      :params => {
        :id => 2,
        :membership => {
          :role_ids => [1]
        }
      }
    )
    assert_response :found
    member = Member.find(2)
    assert member.user.locked?
    assert_equal [1], member.role_ids
  end

  def test_update_should_not_add_unmanaged_roles
    role = Role.find(1)
    role.update! :all_roles_managed => false
    role.managed_roles = Role.where(:id => [2, 3]).to_a
    member = Member.create!(:user => User.find(9), :role_ids => [3], :project_id => 1)

    put(
      :update,
      :params => {
        :id => member.id,
        :membership => {
          :role_ids => [1, 2, 3]
        }
      }
    )
    assert_equal [2, 3], member.reload.role_ids.sort
  end

  def test_update_should_not_remove_unmanaged_roles
    role = Role.find(1)
    role.update! :all_roles_managed => false
    role.managed_roles = Role.where(:id => [2, 3]).to_a
    member = Member.create!(:user => User.find(9), :role_ids => [1, 3], :project_id => 1)

    put(
      :update,
      :params => {
        :id => member.id,
        :membership => {
          :role_ids => [2]
        }
      }
    )
    assert_equal [1, 2], member.reload.role_ids.sort
  end

  def test_xhr_update
    assert_no_difference 'Member.count' do
      put(
        :update,
        :params => {
          :id => 2,
          :membership => {
            :role_ids => [1],
            :user_id => 3
          }
        },
        :xhr => true
      )
      assert_response :success
      assert_equal 'text/javascript', response.media_type
    end
    member = Member.find(2)
    assert_equal [1], member.role_ids
    assert_equal 3, member.user_id
    assert_include 'tab-content-members', response.body
  end

  def test_destroy
    assert_difference 'Member.count', -1 do
      delete(:destroy, :params => {:id => 2})
    end
    assert_redirected_to '/projects/ecookbook/settings/members'
    assert !User.find(3).member_of?(Project.find(1))
  end

  def test_destroy_locked_member_should_be_allowed
    assert User.find(3).lock!

    assert_difference 'Member.count', -1 do
      delete(:destroy, :params => {:id => 2})
    end
  end

  def test_destroy_should_fail_with_unmanaged_roles
    role = Role.find(1)
    role.update! :all_roles_managed => false
    role.managed_roles = Role.where(:id => [2, 3]).to_a
    member = Member.create!(:user => User.find(9), :role_ids => [1, 3], :project_id => 1)

    assert_no_difference 'Member.count' do
      delete(:destroy, :params => {:id => member.id})
    end
  end

  def test_destroy_should_succeed_with_managed_roles_only
    role = Role.find(1)
    role.update! :all_roles_managed => false
    role.managed_roles = Role.where(:id => [2, 3]).to_a
    member = Member.create!(:user => User.find(9), :role_ids => [3], :project_id => 1)

    assert_difference 'Member.count', -1 do
      delete(:destroy, :params => {:id => member.id})
    end
  end

  def test_xhr_destroy
    assert_difference 'Member.count', -1 do
      delete(:destroy, :params => {:id => 2}, :xhr => true)
      assert_response :success
      assert_equal 'text/javascript', response.media_type
    end
    assert_nil Member.find_by_id(2)
    assert_include 'tab-content-members', response.body
  end

  def test_autocomplete
    get(
      :autocomplete,
      :params => {
        :project_id => 1,
        :q => 'mis',
        :format => 'js'
      },
      :xhr => true
    )
    assert_response :success
    assert_include 'User Misc', response.body
  end

  def test_index_html_should_render_members_page
    get(:index, :params => {:project_id => 1})
    assert_response :success
    assert_select 'h2', :text => 'Members'
    assert_select 'div#main-menu a.overview.selected'
    assert_select 'title', :text => 'Members - eCookbook - Redmine'
    assert_select 'form#members-filter-form[action=?]', '/projects/ecookbook/members' do
      assert_select 'input[name=member_name]'
      assert_select 'select[name=member_role_id]'
      assert_select 'input[type=submit]'
      assert_select 'a[href=?]', '/projects/ecookbook/members'
    end
    assert_select 'table.list.members'
  end

  def test_index_html_filter_by_status
    @request.session[:user_id] = 2
    get(:index, :params => {:project_id => 1, :member_status => 3})
    assert_response :success
    assert_select 'table.list.members tbody tr.member', :count => 1
    assert_select 'tr#member-4'
    assert_select 'tr#member-1', :count => 0
    assert_select 'tr#member-2', :count => 0
  end

  def test_index_html_for_user_with_manage_members_permission_should_display_actions
    @request.session[:user_id] = 2 # user 2 has manage_members
    get(:index, :params => {:project_id => 1})
    assert_response :success
    assert_select 'p a.icon-add'
    assert_select 'td.buttons a.icon-edit'
    assert_select 'select[name=member_status]'
  end

  def test_index_html_for_user_without_manage_members_permission_should_not_display_actions
    role = Role.create!(:name => 'Viewer', :permissions => [:view_project, :view_members])
    user = User.generate!
    User.add_to_project(user, Project.find(1), role)
    @request.session[:user_id] = user.id

    get(:index, :params => {:project_id => 1})
    assert_response :success
    assert_select 'p a.icon-add', :count => 0
    assert_select 'td.buttons', :count => 0
    assert_select 'select[name=member_status]', :count => 0
    assert_select 'tr#member-4', :count => 0
  end

  def test_index_html_for_user_without_manage_members_permission_should_only_show_active_members
    role = Role.create!(:name => 'Viewer', :permissions => [:view_project, :view_members])
    user = User.generate!
    User.add_to_project(user, Project.find(1), role)
    @request.session[:user_id] = user.id

    get(:index, :params => {:project_id => 1, :member_status => 3})
    assert_response :success
    assert_select 'select[name=member_status]', :count => 0
    assert_select 'tr#member-4', :count => 0
    assert_select 'tr#member-1'
    assert_select 'tr#member-2'
  end

  def test_index_html_filter_by_name
    get(:index, :params => {:project_id => 1, :member_name => 'John'})
    assert_response :success
    assert_select 'table.list.members tbody tr.member', :count => 1
    assert_select 'tr#member-1'
  end

  def test_index_html_filter_by_role
    get(:index, :params => {:project_id => 1, :member_role_id => 2})
    assert_response :success
    assert_select 'table.list.members tbody tr.member'
    assert_select 'tr#member-2'
    assert_select 'tr#member-1', :count => 0
  end

  def test_index_html_with_pagination
    project = Project.find(1)
    26.times { User.add_to_project(User.generate!, project, Role.find(2)) }
    with_settings :per_page_options => '25,50,100' do
      get(:index, :params => {:project_id => 1, :members_page => 2})
      assert_response :success
      assert_select 'span.pagination'
      assert_select 'span.pagination a[href*=?]', '/projects/ecookbook/members?members_page='
      assert_select 'span.pagination a[href*=?]', 'settings/members', :count => 0
    end
  end

  def test_index_html_unauthorized_user_should_be_denied
    @request.session[:user_id] = nil
    get(:index, :params => {:project_id => 2})
    assert_response :redirect
  end
end
