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

class UsersControllerTest < ActionController::TestCase
  include Redmine::I18n

  fixtures :users, :projects, :members, :member_roles, :roles,
           :custom_fields, :custom_values, :groups_users,
           :auth_sources

  def setup
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'index'
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:users)
    # active users only
    assert_nil assigns(:users).detect {|u| !u.active?}
  end

  def test_index_with_status_filter
    get :index, :status => 3
    assert_response :success
    assert_template 'index'
    assert_not_nil assigns(:users)
    assert_equal [3], assigns(:users).map(&:status).uniq
  end

  def test_index_with_name_filter
    get :index, :name => 'john'
    assert_response :success
    assert_template 'index'
    users = assigns(:users)
    assert_not_nil users
    assert_equal 1, users.size
    assert_equal 'John', users.first.firstname
  end

  def test_index_with_group_filter
    get :index, :group_id => '10'
    assert_response :success
    assert_template 'index'
    users = assigns(:users)
    assert users.any?
    assert_equal([], (users - Group.find(10).users))
    assert_select 'select[name=group_id]' do
      assert_select 'option[value=10][selected=selected]'
    end
  end

  def test_show
    @request.session[:user_id] = nil
    get :show, :id => 2
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:user)

    assert_tag 'li', :content => /Phone number/
  end

  def test_show_should_not_display_hidden_custom_fields
    @request.session[:user_id] = nil
    UserCustomField.find_by_name('Phone number').update_attribute :visible, false
    get :show, :id => 2
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:user)

    assert_no_tag 'li', :content => /Phone number/
  end

  def test_show_should_not_fail_when_custom_values_are_nil
    user = User.find(2)

    # Create a custom field to illustrate the issue
    custom_field = CustomField.create!(:name => 'Testing', :field_format => 'text')
    custom_value = user.custom_values.build(:custom_field => custom_field).save!

    get :show, :id => 2
    assert_response :success
  end

  def test_show_inactive
    @request.session[:user_id] = nil
    get :show, :id => 5
    assert_response 404
  end

  def test_show_should_not_reveal_users_with_no_visible_activity_or_project
    @request.session[:user_id] = nil
    get :show, :id => 9
    assert_response 404
  end

  def test_show_inactive_by_admin
    @request.session[:user_id] = 1
    get :show, :id => 5
    assert_response 200
    assert_not_nil assigns(:user)
  end

  def test_show_displays_memberships_based_on_project_visibility
    @request.session[:user_id] = 1
    get :show, :id => 2
    assert_response :success
    memberships = assigns(:memberships)
    assert_not_nil memberships
    project_ids = memberships.map(&:project_id)
    assert project_ids.include?(2) #private project admin can see
  end

  def test_show_current_should_require_authentication
    @request.session[:user_id] = nil
    get :show, :id => 'current'
    assert_response 302
  end

  def test_show_current
    @request.session[:user_id] = 2
    get :show, :id => 'current'
    assert_response :success
    assert_template 'show'
    assert_equal User.find(2), assigns(:user)
  end

  def test_new
    get :new
    assert_response :success
    assert_template :new
    assert assigns(:user)
  end

  def test_create
    Setting.bcc_recipients = '1'

    assert_difference 'User.count' do
      assert_difference 'ActionMailer::Base.deliveries.size' do
        post :create,
          :user => {
            :firstname => 'John',
            :lastname => 'Doe',
            :login => 'jdoe',
            :password => 'secret123',
            :password_confirmation => 'secret123',
            :mail => 'jdoe@gmail.com',
            :mail_notification => 'none'
          },
          :send_information => '1'
      end
    end

    user = User.first(:order => 'id DESC')
    assert_redirected_to :controller => 'users', :action => 'edit', :id => user.id

    assert_equal 'John', user.firstname
    assert_equal 'Doe', user.lastname
    assert_equal 'jdoe', user.login
    assert_equal 'jdoe@gmail.com', user.mail
    assert_equal 'none', user.mail_notification
    assert user.check_password?('secret123')

    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_equal [user.mail], mail.bcc
    assert_mail_body_match 'secret', mail
  end

  def test_create_with_preferences
    assert_difference 'User.count' do
      post :create,
        :user => {
          :firstname => 'John',
          :lastname => 'Doe',
          :login => 'jdoe',
          :password => 'secret123',
          :password_confirmation => 'secret123',
          :mail => 'jdoe@gmail.com',
          :mail_notification => 'none'
        },
        :pref => {
          'hide_mail' => '1',
          'time_zone' => 'Paris',
          'comments_sorting' => 'desc',
          'warn_on_leaving_unsaved' => '0'
        }
    end
    user = User.first(:order => 'id DESC')
    assert_equal 'jdoe', user.login
    assert_equal true, user.pref.hide_mail
    assert_equal 'Paris', user.pref.time_zone
    assert_equal 'desc', user.pref[:comments_sorting]
    assert_equal '0', user.pref[:warn_on_leaving_unsaved]
  end

  def test_create_with_generate_password_should_email_the_password
    assert_difference 'User.count' do
      post :create, :user => {
        :login => 'randompass',
        :firstname => 'Random',
        :lastname => 'Pass',
        :mail => 'randompass@example.net',
        :language => 'en',
        :generate_password => '1',
        :password => '',
        :password_confirmation => ''
      }, :send_information => 1
    end
    user = User.order('id DESC').first
    assert_equal 'randompass', user.login

    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    m = mail_body(mail).match(/Password: ([a-zA-Z0-9]+)/)
    assert m
    password = m[1]
    assert user.check_password?(password)
  end

  def test_create_with_failure
    assert_no_difference 'User.count' do
      post :create, :user => {}
    end
    assert_response :success
    assert_template 'new'
  end

  def test_edit
    get :edit, :id => 2
    assert_response :success
    assert_template 'edit'
    assert_equal User.find(2), assigns(:user)
  end

  def test_update
    ActionMailer::Base.deliveries.clear
    put :update, :id => 2,
        :user => {:firstname => 'Changed', :mail_notification => 'only_assigned'},
        :pref => {:hide_mail => '1', :comments_sorting => 'desc'}
    user = User.find(2)
    assert_equal 'Changed', user.firstname
    assert_equal 'only_assigned', user.mail_notification
    assert_equal true, user.pref[:hide_mail]
    assert_equal 'desc', user.pref[:comments_sorting]
    assert ActionMailer::Base.deliveries.empty?
  end

  def test_update_with_failure
    assert_no_difference 'User.count' do
      put :update, :id => 2, :user => {:firstname => ''}
    end
    assert_response :success
    assert_template 'edit'
  end

  def test_update_with_group_ids_should_assign_groups
    put :update, :id => 2, :user => {:group_ids => ['10']}
    user = User.find(2)
    assert_equal [10], user.group_ids
  end

  def test_update_with_activation_should_send_a_notification
    u = User.new(:firstname => 'Foo', :lastname => 'Bar', :mail => 'foo.bar@somenet.foo', :language => 'fr')
    u.login = 'foo'
    u.status = User::STATUS_REGISTERED
    u.save!
    ActionMailer::Base.deliveries.clear
    Setting.bcc_recipients = '1'

    put :update, :id => u.id, :user => {:status => User::STATUS_ACTIVE}
    assert u.reload.active?
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_equal ['foo.bar@somenet.foo'], mail.bcc
    assert_mail_body_match ll('fr', :notice_account_activated), mail
  end

  def test_update_with_password_change_should_send_a_notification
    ActionMailer::Base.deliveries.clear
    Setting.bcc_recipients = '1'

    put :update, :id => 2, :user => {:password => 'newpass123', :password_confirmation => 'newpass123'}, :send_information => '1'
    u = User.find(2)
    assert u.check_password?('newpass123')

    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_equal [u.mail], mail.bcc
    assert_mail_body_match 'newpass123', mail
  end

  def test_update_with_generate_password_should_email_the_password
    ActionMailer::Base.deliveries.clear
    Setting.bcc_recipients = '1'

    put :update, :id => 2, :user => {
      :generate_password => '1',
      :password => '',
      :password_confirmation => ''
    }, :send_information => '1'

    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    m = mail_body(mail).match(/Password: ([a-zA-Z0-9]+)/)
    assert m
    password = m[1]
    assert User.find(2).check_password?(password)
  end

  def test_update_without_generate_password_should_not_change_password
    put :update, :id => 2, :user => {
      :firstname => 'changed',
      :generate_password => '0',
      :password => '',
      :password_confirmation => ''
    }, :send_information => '1'

    user = User.find(2)
    assert_equal 'changed', user.firstname
    assert user.check_password?('jsmith')
  end

  def test_update_user_switchin_from_auth_source_to_password_authentication
    # Configure as auth source
    u = User.find(2)
    u.auth_source = AuthSource.find(1)
    u.save!

    put :update, :id => u.id, :user => {:auth_source_id => '', :password => 'newpass123', :password_confirmation => 'newpass123'}

    assert_equal nil, u.reload.auth_source
    assert u.check_password?('newpass123')
  end

  def test_update_notified_project
    get :edit, :id => 2
    assert_response :success
    assert_template 'edit'
    u = User.find(2)
    assert_equal [1, 2, 5], u.projects.collect{|p| p.id}.sort
    assert_equal [1, 2, 5], u.notified_projects_ids.sort
    assert_select 'input[name=?][value=?]', 'user[notified_project_ids][]', '1'
    assert_equal 'all', u.mail_notification
    put :update, :id => 2,
        :user => {
          :mail_notification => 'selected',
          :notified_project_ids => [1, 2]
        }
    u = User.find(2)
    assert_equal 'selected', u.mail_notification
    assert_equal [1, 2], u.notified_projects_ids.sort
  end

  def test_update_status_should_not_update_attributes
    user = User.find(2)
    user.pref[:no_self_notified] = '1'
    user.pref.save

    put :update, :id => 2, :user => {:status => 3}
    assert_response 302
    user = User.find(2)
    assert_equal 3, user.status
    assert_equal '1', user.pref[:no_self_notified]
  end

  def test_destroy
    assert_difference 'User.count', -1 do
      delete :destroy, :id => 2
    end
    assert_redirected_to '/users'
    assert_nil User.find_by_id(2)
  end

  def test_destroy_should_be_denied_for_non_admin_users
    @request.session[:user_id] = 3

    assert_no_difference 'User.count' do
      get :destroy, :id => 2
    end
    assert_response 403
  end

  def test_destroy_should_redirect_to_back_url_param
    assert_difference 'User.count', -1 do
      delete :destroy, :id => 2, :back_url => '/users?name=foo'
    end
    assert_redirected_to '/users?name=foo'
  end

  def test_create_membership
    assert_difference 'Member.count' do
      post :edit_membership, :id => 7, :membership => { :project_id => 3, :role_ids => [2]}
    end
    assert_redirected_to :action => 'edit', :id => '7', :tab => 'memberships'
    member = Member.first(:order => 'id DESC')
    assert_equal User.find(7), member.principal
    assert_equal [2], member.role_ids
    assert_equal 3, member.project_id
  end

  def test_create_membership_js_format
    assert_difference 'Member.count' do
      post :edit_membership, :id => 7, :membership => {:project_id => 3, :role_ids => [2]}, :format => 'js'
      assert_response :success
      assert_template 'edit_membership'
      assert_equal 'text/javascript', response.content_type
    end
    member = Member.first(:order => 'id DESC')
    assert_equal User.find(7), member.principal
    assert_equal [2], member.role_ids
    assert_equal 3, member.project_id
    assert_include 'tab-content-memberships', response.body
  end

  def test_create_membership_js_format_with_failure
    assert_no_difference 'Member.count' do
      post :edit_membership, :id => 7, :membership => {:project_id => 3}, :format => 'js'
      assert_response :success
      assert_template 'edit_membership'
      assert_equal 'text/javascript', response.content_type
    end
    assert_include 'alert', response.body, "Alert message not sent"
    assert_include 'Role can\\\'t be empty', response.body, "Error message not sent"
  end

  def test_update_membership
    assert_no_difference 'Member.count' do
      put :edit_membership, :id => 2, :membership_id => 1, :membership => { :role_ids => [2]}
      assert_redirected_to :action => 'edit', :id => '2', :tab => 'memberships'
    end
    assert_equal [2], Member.find(1).role_ids
  end

  def test_update_membership_js_format
    assert_no_difference 'Member.count' do
      put :edit_membership, :id => 2, :membership_id => 1, :membership => {:role_ids => [2]}, :format => 'js'
      assert_response :success
      assert_template 'edit_membership'
      assert_equal 'text/javascript', response.content_type
    end
    assert_equal [2], Member.find(1).role_ids
    assert_include 'tab-content-memberships', response.body
  end

  def test_destroy_membership
    assert_difference 'Member.count', -1 do
      delete :destroy_membership, :id => 2, :membership_id => 1
    end
    assert_redirected_to :action => 'edit', :id => '2', :tab => 'memberships'
    assert_nil Member.find_by_id(1)
  end

  def test_destroy_membership_js_format
    assert_difference 'Member.count', -1 do
      delete :destroy_membership, :id => 2, :membership_id => 1, :format => 'js'
      assert_response :success
      assert_template 'destroy_membership'
      assert_equal 'text/javascript', response.content_type
    end
    assert_nil Member.find_by_id(1)
    assert_include 'tab-content-memberships', response.body
  end
end
