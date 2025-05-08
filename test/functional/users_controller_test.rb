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

class UsersControllerTest < Redmine::ControllerTest
  include Redmine::I18n

  def setup
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end

  def test_index
    get :index
    assert_response :success
    active = User.active.first
    locked = User.where(status: User::STATUS_LOCKED).first
    assert_select 'table.users'
    assert_select "tr#user-#{active.id}"
    assert_select "tr#user-#{locked.id}", 0
  end

  def test_index_with_status_filter
    get :index, params: { set_filter: 1, f: ['status'], op: {status: '='}, v: {status: [3]} }
    assert_response :success
    assert_select "tr.user", User.where(status: 3).count
  end

  def test_index_with_firstname_filter
    get :index, params: { set_filter: 1, f: ['firstname'], op: {firstname: '~'}, v: {firstname: ['john']} }
    assert_response :success
    assert_select 'tr.user td.login', text: 'jsmith'
    assert_select 'tr.user', 1
  end

  def test_index_with_group_filter
    get :index, params: {
      set_filter: 1,
      f: ['is_member_of_group'], op: {is_member_of_group: '='}, v: {is_member_of_group: ['10']}
    }
    assert_response :success
    assert_select 'tr.user', Group.find(10).users.count
  end

  def test_index_should_not_show_2fa_filter_and_column_if_disabled
    with_settings twofa: "0" do
      get :index
      assert_response :success

      assert_select "select#add_filter_select" do
        assert_select "option[value=twofa_scheme]", 0
      end
      assert_select "select#available_c" do
        assert_select "option[value=twofa_scheme]", 0
      end
    end
  end

  def test_index_filter_by_twofa_yes
    with_settings twofa: "1" do
      user = User.find(1)
      user.twofa_totp_key = "AVYA3RARZ3GY3VWT7MIEJ72I5TTJRO3X"
      user.twofa_scheme = "totp"
      user.save

      get :index, params: { set_filter: 1, f: ['twofa_scheme'], op: {twofa_scheme: '*'} }
      assert_response :success

      assert_select 'tr#user-1', 1
      assert_select 'tr.user', 1

      assert_select "select#add_filter_select" do
        assert_select "option[value=twofa_scheme]"
      end
      assert_select "select#available_c" do
        assert_select "option[value=twofa_scheme]"
      end
    end
  end

  def test_index_filter_by_twofa_scheme
    with_settings twofa: "1" do
      user = User.find(1)
      user.twofa_totp_key = "AVYA3RARZ3GY3VWT7MIEJ72I5TTJRO3X"
      user.twofa_scheme = "totp"
      user.save

      get :index, params: {
        set_filter: 1,
        f: ['twofa_scheme'], op: {twofa_scheme: '='}, v: {twofa_scheme: ['totp']}
      }
      assert_response :success

      assert_select 'tr#user-1', 1

      assert_select "select#add_filter_select" do
        assert_select "option[value=twofa_scheme]"
      end
      assert_select "select#available_c" do
        assert_select "option[value=twofa_scheme]"
      end
    end
  end

  def test_index_filter_by_twofa_no
    with_settings twofa: "1" do
      user = User.find(1)
      user.twofa_totp_key = "AVYA3RARZ3GY3VWT7MIEJ72I5TTJRO3X"
      user.twofa_scheme = "totp"
      user.save

      get :index, params: { set_filter: 1, f: ['twofa_scheme'], op: {twofa_scheme: '!*'} }
      assert_response :success

      assert_select 'tr#user-1', 0
      assert_select 'tr.user'
    end
  end

  def test_index_filter_by_auth_source_none
    user = User.find(1)
    user.update_column :auth_source_id, 1

    get :index, params: {
      set_filter: 1,
      f: ['auth_source_id'], op: {auth_source_id: '!*'}
    }
    assert_response :success

    assert_select 'tr.user'
    assert_select 'tr#user-1', 0
  end

  def test_index_filter_by_auth_source
    user = User.find(1)
    user.update_column :auth_source_id, 1

    get :index, params: {
      set_filter: 1,
      f: ['auth_source_id'], op: {auth_source_id: '='}, v: {auth_source_id: ['1']}
    }
    assert_response :success

    assert_select 'tr#user-1', 1

    assert_select "select#add_filter_select" do
      assert_select "option[value=auth_source_id]"
    end
    assert_select "select#available_c" do
      assert_select "option[value='auth_source.name']"
    end
  end

  def test_index_with_auth_source_column
    user = User.find(1)
    user.update_column :auth_source_id, 1

    get :index, params: {
      set_filter: 1,
      f: ['auth_source_id'], op: {auth_source_id: '='}, v: {auth_source_id: ['1']},
      c: %w(login firstname lastname mail auth_source.name)
    }
    assert_response :success

    assert_select 'tr#user-1', 1
  end

  def test_index_with_query
    query = UserQuery.create!(:name => 'My User Query', :description => 'Description for My User Query', :visibility => UserQuery::VISIBILITY_PUBLIC)
    get :index, :params => { :query_id => query.id }
    assert_response :success

    assert_select 'h2', :text => query.name
    assert_select '#sidebar a.query.selected[title=?]', query.description, :text => query.name
  end

  def test_index_csv
    with_settings :default_language => 'en' do
      user = User.logged.status(1).first
      user.update(passwd_changed_on: Time.current.last_month, twofa_scheme: 'totp')
      get :index, params: {format: 'csv', c: ['updated_on', 'status', 'passwd_changed_on', 'twofa_scheme']}
      assert_response :success

      assert_equal User.logged.status(1).count, response.body.chomp.split("\n").size - 1
      assert_include format_time(user.updated_on), response.body.split("\n").second
      assert_include format_time(user.passwd_changed_on), response.body.split("\n").second

      # status
      assert_include 'active', response.body.split("\n").second
      assert_not_include 'locked', response.body.split("\n").second

      # twofa_scheme
      assert_include 'Authenticator app', response.body.split("\n").second
      assert_include 'disabled', response.body.split("\n").third

      assert_equal 'text/csv; header=present', @response.media_type
    end
  end

  def test_index_csv_with_custom_field_columns
    float_custom_field = UserCustomField.generate!(:name => 'float field', :field_format => 'float')
    date_custom_field = UserCustomField.generate!(:name => 'date field', :field_format => 'date')
    user = User.last
    user.custom_field_values = {float_custom_field.id.to_s => 2.1, date_custom_field.id.to_s => '2020-01-10'}
    user.save

    User.find(@request.session[:user_id]).update(:language => nil)
    with_settings :default_language => 'fr' do
      get :index, params: {
        c: ["cf_#{float_custom_field.id}", "cf_#{date_custom_field.id}"],
        f: ["name"],
        op: { name: "~" },
        v: { name: [user.lastname] },
        format: 'csv'
      }
      assert_response :success

      assert_include 'float field;date field', response.body
      assert_include '2,10;10/01/2020', response.body
      assert_equal 'text/csv; header=present', @response.media_type
    end
  end

  def test_index_csv_with_status_filter
    with_settings :default_language => 'en' do
      get :index, :params => {
        :set_filter => '1',
        :f => [:status], :op => { :status => '=' }, :v => { :status => [3] },
        :c => [:login, :status],
        :format => 'csv'
      }
      assert_response :success

      assert_equal User.logged.status(3).count, response.body.chomp.split("\n").size - 1
      assert_include 'locked', response.body
      assert_not_include 'active', response.body
      assert_equal 'text/csv; header=present', @response.media_type
    end
  end

  def test_index_csv_with_name_filter
    get :index, :params => {
      :set_filter => '1',
      :f => [:firstname], :op => { :firstname => '~' }, :v => { :firstname => ['John'] },
      :c => [:login, :firstname, :status],
      :format => 'csv'
    }
    assert_response :success

    assert_equal User.logged.like('John').count, response.body.chomp.split("\n").size - 1
    assert_include 'John', response.body
    assert_equal 'text/csv; header=present', @response.media_type
  end

  def test_index_csv_with_group_filter
    get :index, :params => {
      :set_filter => '1',
      :f => [:is_member_of_group], :op => { :is_member_of_group => '=' }, :v => { :is_member_of_group => [10] },
      :c => [:login, :status],
      :format => 'csv'
    }
    assert_response :success

    assert_equal Group.find(10).users.count, response.body.chomp.split("\n").size - 1
    assert_equal 'text/csv; header=present', @response.media_type
  end

  def test_index_csv_filename_without_query_id_param
    get :index, :params => {:format => 'csv'}
    assert_response :success
    assert_match /users.csv/, @response.headers['Content-Disposition']
  end

  def test_index_csv_filename_with_query_id_param
    query = UserQuery.create!(:name => 'My Query Name', :visibility => UserQuery::VISIBILITY_PUBLIC)
    get :index, :params => {:query_id => query.id, :format => 'csv'}
    assert_response :success
    assert_match /my_query_name\.csv/, @response.headers['Content-Disposition']
  end

  def test_show
    @request.session[:user_id] = nil
    get :show, :params => {:id => 2}
    assert_response :success
    assert_select 'h2', :text => /John Smith/

    # groups block should not be rendeder for users which are not part of any group
    assert_select 'div#groups', 0
  end

  def test_show_should_display_visible_custom_fields
    @request.session[:user_id] = nil
    UserCustomField.find_by_name('Phone number').update_attribute :visible, true
    get :show, :params => {:id => 2}
    assert_response :success

    assert_select 'li.cf_4.string_cf', :text => /Phone number/
  end

  def test_show_should_not_display_hidden_custom_fields
    @request.session[:user_id] = nil
    UserCustomField.find_by_name('Phone number').update_attribute :visible, false
    get :show, :params => {:id => 2}
    assert_response :success

    assert_select 'li', :text => /Phone number/, :count => 0
  end

  def test_show_should_not_fail_when_custom_values_are_nil
    user = User.find(2)

    # Create a custom field to illustrate the issue
    custom_field = CustomField.create!(:name => 'Testing', :field_format => 'text')
    custom_value = user.custom_values.build(:custom_field => custom_field).save!

    get :show, :params => {:id => 2}
    assert_response :success
  end

  def test_show_inactive
    @request.session[:user_id] = nil
    get :show, :params => {:id => 5}
    assert_response :not_found
  end

  def test_show_inactive_by_admin
    @request.session[:user_id] = 1
    get :show, :params => {:id => 5}
    assert_response :ok
    assert_select 'h2', :text => /Dave2 Lopper2/
  end

  def test_show_user_who_is_not_visible_should_return_404
    Role.anonymous.update! :users_visibility => 'members_of_visible_projects'
    user = User.generate!

    @request.session[:user_id] = nil
    get :show, :params => {:id => user.id}
    assert_response :not_found
  end

  def test_show_displays_memberships_based_on_project_visibility
    @request.session[:user_id] = 1
    get :show, :params => {:id => 2}
    assert_response :success

    assert_select 'table.list.projects>tbody' do
      assert_select 'tr:nth-of-type(1)' do
        assert_select 'td:nth-of-type(1)>span>a', :text => 'eCookbook'
        assert_select 'td:nth-of-type(2)', :text => 'Manager'
      end
      assert_select 'tr:nth-of-type(2)' do
        assert_select 'td:nth-of-type(1)>span>a', :text => 'Private child of eCookbook'
        assert_select 'td:nth-of-type(2)', :text => 'Manager'
      end
      assert_select 'tr:nth-of-type(3)' do
        assert_select 'td:nth-of-type(1)>span>a', :text => 'OnlineStore'
        assert_select 'td:nth-of-type(2)', :text => 'Developer'
      end
    end
  end

  def test_show_current_should_require_authentication
    @request.session[:user_id] = nil
    get :show, :params => {:id => 'current'}
    assert_response :found
  end

  def test_show_current
    @request.session[:user_id] = 2
    get :show, :params => {:id => 'current'}
    assert_response :success
    assert_select 'h2', :text => /John Smith/
  end

  def test_show_issues_counts
    @request.session[:user_id] = 2
    get :show, :params => {:id => 2}
    assert_select 'table.list.issue-report>tbody' do
      assert_select 'tr:nth-of-type(1)' do
        assert_select 'td:nth-of-type(1)>a', :text => 'Assigned issues'
        assert_select 'td:nth-of-type(2)>a', :text => '1'   # open
        assert_select 'td:nth-of-type(3)>a', :text => '0'   # closed
        assert_select 'td:nth-of-type(4)>a', :text => '1'   # total
      end
      assert_select 'tr:nth-of-type(2)' do
        assert_select 'td:nth-of-type(1)>a', :text => 'Reported issues'
        assert_select 'td:nth-of-type(2)>a', :text => '11'  # open
        assert_select 'td:nth-of-type(3)>a', :text => '2'   # closed
        assert_select 'td:nth-of-type(4)>a', :text => '13'  # total
      end
    end
  end

  def test_show_user_should_list_user_groups
    @request.session[:user_id] = 1
    get :show, :params => {:id => 8}

    assert_select 'div#groups', 1 do
      assert_select 'h3', :text => 'Groups'
      assert_select 'li', 2
      assert_select 'a[href=?]', '/groups/10/edit', :text => 'A Team'
      assert_select 'a[href=?]', '/groups/11/edit', :text => 'B Team'
    end
  end

  def test_show_should_list_all_emails
    EmailAddress.create!(user_id: 3, address: 'dlopper@example.net')
    EmailAddress.create!(user_id: 3, address: 'dlopper@example.org')

    @request.session[:user_id] = 1
    get :show, params: {id: 3}

    assert_select 'li', text: /Email:/ do
      assert_select 'a:nth-of-type(1)', text: 'dlopper@somenet.foo'
      assert_select 'a:nth-of-type(2)', text: 'dlopper@example.net'
      assert_select 'a:nth-of-type(3)', text: 'dlopper@example.org'
    end
  end

  def test_new
    get :new
    assert_response :success
    assert_select 'input[name=?]', 'user[login]'
    assert_select 'label[for=?]>span.required', 'user_password', 1
  end

  def test_create
    assert_difference 'User.count' do
      assert_difference 'ActionMailer::Base.deliveries.size' do
        post :create, :params => {
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
        }
      end
    end

    user = User.order('id DESC').first
    assert_redirected_to :controller => 'users', :action => 'edit', :id => user.id

    assert_equal 'John', user.firstname
    assert_equal 'Doe', user.lastname
    assert_equal 'jdoe', user.login
    assert_equal 'jdoe@gmail.com', user.mail
    assert_equal 'none', user.mail_notification
    assert user.check_password?('secret123')

    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_equal [user.mail], mail.to
    assert_mail_body_match 'secret', mail
  end

  def test_create_with_preferences
    assert_difference 'User.count' do
      post :create, :params => {
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
          'warn_on_leaving_unsaved' => '0',
          'textarea_font' => 'proportional',
          'history_default_tab' => 'history'
        }
      }
    end
    user = User.order('id DESC').first
    assert_equal 'jdoe', user.login
    assert_equal true, user.pref.hide_mail
    assert_equal 'Paris', user.pref.time_zone
    assert_equal 'desc', user.pref[:comments_sorting]
    assert_equal '0', user.pref[:warn_on_leaving_unsaved]
    assert_equal 'proportional', user.pref[:textarea_font]
    assert_equal 'history', user.pref[:history_default_tab]
  end

  def test_create_with_generate_password_should_email_the_password
    assert_difference 'User.count' do
      post :create, :params => {
        :user => {
          :login => 'randompass',
          :firstname => 'Random',
          :lastname => 'Pass',
          :mail => 'randompass@example.net',
          :language => 'en',
          :generate_password => '1',
          :password => '',
          :password_confirmation => ''
        },
        :send_information => 1
      }
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

  def test_create_and_continue
    post :create, :params => {
      :user => {
        :login => 'randompass',
        :firstname => 'Random',
        :lastname => 'Pass',
        :mail => 'randompass@example.net',
        :generate_password => '1'
      },
      :continue => '1'
    }
    assert_redirected_to '/users/new?user%5Bgenerate_password%5D=1'
  end

  def test_create_with_failure
    assert_no_difference 'User.count' do
      post :create, :params => {:user => {:login => 'foo'}}
    end
    assert_response :success
    assert_select_error /Email cannot be blank/
  end

  def test_create_with_failure_sould_preserve_preference
    assert_no_difference 'User.count' do
      post :create, :params => {
        :user => {
          :login => 'foo'
        },
        :pref => {
          'no_self_notified' => '1',
          'hide_mail' => '1',
          'time_zone' => 'Paris',
          'comments_sorting' => 'desc',
          'warn_on_leaving_unsaved' => '0'
        }
      }
    end
    assert_response :success

    assert_select 'select#pref_time_zone option[selected=selected]', :text => /Paris/
    assert_select 'input#pref_no_self_notified[value="1"][checked=checked]'
  end

  def test_create_admin_should_send_security_notification
    ActionMailer::Base.deliveries.clear
    post :create, :params => {
      :user => {
        :firstname => 'Edgar',
        :lastname => 'Schmoe',
        :login => 'eschmoe',
        :password => 'secret123',
        :password_confirmation => 'secret123',
        :mail => 'eschmoe@example.foo',
        :admin => '1'
      }
    }

    assert_not_nil (mail = ActionMailer::Base.deliveries.last)
    assert_mail_body_match '0.0.0.0', mail
    assert_mail_body_match(
      I18n.t(
        :mail_body_security_notification_add,
        field: I18n.t(:field_admin),
        value: 'eschmoe'
      ),
      mail
    )
    assert_select_email do
      assert_select 'a[href^=?]', 'http://localhost:3000/users', :text => 'Users'
    end

    # All admins should receive this
    User.where(admin: true, status: Principal::STATUS_ACTIVE).each do |admin|
      assert_not_nil(
        ActionMailer::Base.deliveries.detect do |mail|
          [mail.to].flatten.include?(admin.mail)
        end
      )
    end
  end

  def test_create_non_admin_should_not_send_security_notification
    ActionMailer::Base.deliveries.clear

    post :create, :params => {
      :user => {
        :firstname => 'Edgar',
        :lastname => 'Schmoe',
        :login => 'eschmoe',
        :password => 'secret123',
        :password_confirmation => 'secret123',
        :mail => 'eschmoe@example.foo',
        :admin => '0'
      }
    }

    assert_nil ActionMailer::Base.deliveries.last
  end

  def test_edit
    with_settings :gravatar_enabled => '1' do
      get :edit, :params => {:id => 2}
    end

    assert_response :success
    assert_select 'h2>a+img.gravatar'
    assert_select 'input[name=?][value=?]', 'user[login]', 'jsmith'
    assert_select 'label[for=?]>span.required', 'user_password', 0
  end

  def test_edit_registered_user
    assert User.find(2).register!

    get :edit, :params => {:id => 2}
    assert_response :success
    assert_select 'a', :text => 'Activate'
  end

  def test_edit_should_be_denied_for_anonymous
    assert User.find(6).anonymous?

    get :edit, :params => {:id => 6}

    assert_response :not_found
  end

  def test_edit_user_with_full_text_formatting_custom_field_should_not_fail
    field = UserCustomField.find(4)
    field.update_attribute :text_formatting, 'full'

    get :edit, :params => {:id => 2}

    assert_response :success
  end

  def test_update
    ActionMailer::Base.deliveries.clear

    put :update, :params => {
      :id => 2,
      :user => {:firstname => 'Changed', :mail_notification => 'only_assigned'},
      :pref => {:hide_mail => '1', :comments_sorting => 'desc'}
    }

    user = User.find(2)
    assert_equal 'Changed', user.firstname
    assert_equal 'only_assigned', user.mail_notification
    assert_equal true, user.pref[:hide_mail]
    assert_equal 'desc', user.pref[:comments_sorting]
    assert ActionMailer::Base.deliveries.empty?
  end

  def test_update_with_failure
    assert_no_difference 'User.count' do
      put :update, :params => {
        :id => 2,
        :user => {:firstname => ''}
      }
    end
    assert_response :success
    assert_select_error /First name cannot be blank/
  end

  def test_update_with_group_ids_should_assign_groups
    put :update, :params => {
      :id => 2,
      :user => {:group_ids => ['10']}
    }

    user = User.find(2)
    assert_equal [10], user.group_ids
  end

  def test_update_with_activation_should_send_a_notification
    u = User.new(:firstname => 'Foo', :lastname => 'Bar',
                 :mail => 'foo.bar@somenet.foo', :language => 'fr')
    u.login = 'foo'
    u.status = User::STATUS_REGISTERED
    u.save!
    ActionMailer::Base.deliveries.clear

    put(
      :update,
      :params => {
        :id => u.id,
        :user => {:status => User::STATUS_ACTIVE}
      }
    )

    assert u.reload.active?
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_equal ['foo.bar@somenet.foo'], mail.to
    assert_mail_body_match ll('fr', :notice_account_activated), mail
  end

  def test_update_with_password_change_should_send_a_notification
    ActionMailer::Base.deliveries.clear

    put(
      :update,
      :params => {
        :id => 2,
        :user => {
          :password => 'newpass123',
          :password_confirmation => 'newpass123'
        },
       :send_information => '1'
      }
    )
    u = User.find(2)
    assert u.check_password?('newpass123')

    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_equal [u.mail], mail.to
    assert_mail_body_match 'newpass123', mail
  end

  def test_update_with_password_change_by_admin_should_send_a_security_notification
    ActionMailer::Base.deliveries.clear
    user = User.find_by(login: 'jsmith')

    put :update, :params => {
      :id => user.id,
      :user => {:password => 'newpass123', :password_confirmation => 'newpass123'}
    }

    assert_equal 1, ActionMailer::Base.deliveries.size
    mail = ActionMailer::Base.deliveries.last
    assert_equal [user.mail], mail.to
    assert_match 'Security notification', mail.subject
    assert_mail_body_match 'Your password has been changed.', mail
  end

  def test_update_with_generate_password_should_email_the_password
    ActionMailer::Base.deliveries.clear

    put(
      :update,
      :params => {
        :id => 2,
        :user => {
          :generate_password => '1',
          :password => '',
          :password_confirmation => ''
        },
        :send_information => '1'
      }
    )

    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    u = User.find(2)
    assert_equal [u.mail], mail.to
    m = mail_body(mail).match(/Password: ([a-zA-Z0-9]+)/)
    assert m
    password = m[1]
    assert u.check_password?(password)
  end

  def test_update_without_generate_password_should_not_change_password
    put(
      :update,
      :params => {
        :id => 2,
        :user => {
          :firstname => 'changed',
          :generate_password => '0',
          :password => '',
          :password_confirmation => ''
        },
        :send_information => '1'
      }
    )
    user = User.find(2)
    assert_equal 'changed', user.firstname
    assert user.check_password?('jsmith')
  end

  def test_update_user_switchin_from_auth_source_to_password_authentication
    # Configure as auth source
    u = User.find(2)
    u.auth_source = AuthSource.find(1)
    u.save!

    put :update, :params => {
      :id => u.id,
      :user => {:auth_source_id => '', :password => 'newpass123', :password_confirmation => 'newpass123'}
    }

    assert_nil u.reload.auth_source
    assert u.check_password?('newpass123')
  end

  def test_update_notified_project
    get :edit, :params => {:id => 2}
    assert_response :success
    u = User.find(2)
    assert_equal [1, 2, 5], u.projects.collect{|p| p.id}.sort
    assert_equal [1, 2, 5], u.notified_projects_ids.sort
    assert_select 'input[name=?][value=?]', 'user[notified_project_ids][]', '1'
    assert_equal 'all', u.mail_notification
    put :update, :params => {
      :id => 2,
      :user => {
        :mail_notification => 'selected',
        :notified_project_ids => [1, 2]
      }
    }
    u = User.find(2)
    assert_equal 'selected', u.mail_notification
    assert_equal [1, 2], u.notified_projects_ids.sort
  end

  def test_update_status_should_not_update_attributes
    user = User.find(2)
    user.pref[:no_self_notified] = '1'
    user.pref.save

    put :update, :params => {
      :id => 2,
      :user => {:status => 3}
    }
    assert_response :found
    user = User.find(2)
    assert_equal 3, user.status
    assert_equal '1', user.pref[:no_self_notified]
  end

  def test_update_assign_admin_should_send_security_notification
    ActionMailer::Base.deliveries.clear
    put :update, :params => {
      :id => 2,
      :user => {:admin => 1}
    }

    assert_not_nil (mail = ActionMailer::Base.deliveries.last)
    assert_mail_body_match(
      I18n.t(
        :mail_body_security_notification_add,
        field: I18n.t(:field_admin),
        value: User.find(2).login
      ),
      mail
    )
    # All admins should receive this
    User.where(admin: true, status: Principal::STATUS_ACTIVE).each do |admin|
      assert_not_nil(
        ActionMailer::Base.deliveries.detect do |mail|
          [mail.to].flatten.include?(admin.mail)
        end
      )
    end
  end

  def test_update_unassign_admin_should_send_security_notification
    user = User.find(2)
    user.admin = true
    user.save!

    ActionMailer::Base.deliveries.clear
    put :update, :params => {
      :id => user.id,
      :user => {:admin => 0}
    }

    assert_not_nil (mail = ActionMailer::Base.deliveries.last)
    assert_mail_body_match(
      I18n.t(
        :mail_body_security_notification_remove,
        field: I18n.t(:field_admin),
        value: user.login
      ),
      mail
    )
    # All admins should receive this
    User.where(admin: true, status: Principal::STATUS_ACTIVE).each do |admin|
      assert_not_nil(
        ActionMailer::Base.deliveries.detect do |mail|
          [mail.to].flatten.include?(admin.mail)
        end
      )
    end
  end

  def test_update_lock_admin_should_send_security_notification
    user = User.find(2)
    user.admin = true
    user.save!

    ActionMailer::Base.deliveries.clear
    put :update, :params => {
      :id => 2,
      :user => {:status => Principal::STATUS_LOCKED}
    }

    assert_not_nil (mail = ActionMailer::Base.deliveries.last)
    assert_mail_body_match(
      I18n.t(
        :mail_body_security_notification_remove,
        field: I18n.t(:field_admin),
        value: User.find(2).login
      ),
      mail
    )
    # All admins should receive this
    User.where(admin: true, status: Principal::STATUS_ACTIVE).each do |admin|
      assert_not_nil(
        ActionMailer::Base.deliveries.detect do |mail|
          [mail.to].flatten.include?(admin.mail)
        end
      )
    end

    # if user is already locked, destroying should not send a second mail
    # (for active admins see furtherbelow)
    ActionMailer::Base.deliveries.clear
    delete :destroy, :params => {:id => 1, :confirm => User.find(1).login}
    assert_nil ActionMailer::Base.deliveries.last
  end

  def test_update_unlock_admin_should_send_security_notification
    user = User.find(5) # already locked
    user.admin = true
    user.save!
    ActionMailer::Base.deliveries.clear
    put :update, :params => {
      :id => user.id,
      :user => {:status => Principal::STATUS_ACTIVE}
    }

    assert_not_nil (mail = ActionMailer::Base.deliveries.last)
    assert_mail_body_match(
      I18n.t(
        :mail_body_security_notification_add,
        field: I18n.t(:field_admin),
        value: user.login
      ),
      mail
    )
    # All admins should receive this
    User.where(admin: true, status: Principal::STATUS_ACTIVE).each do |admin|
      assert_not_nil(
        ActionMailer::Base.deliveries.detect do |mail|
          [mail.to].flatten.include?(admin.mail)
        end
      )
    end
  end

  def test_update_admin_unrelated_property_should_not_send_security_notification
    ActionMailer::Base.deliveries.clear
    put :update, :params => {
      :id => 1,
      :user => {:firstname => 'Jimmy'}
    }
    assert_nil ActionMailer::Base.deliveries.last
  end

  def test_update_should_be_denied_for_anonymous
    assert User.find(6).anonymous?
    put :update, :params => {:id => 6}
    assert_response :not_found
  end

  def test_update_with_blank_email_should_not_raise_exception
    assert_no_difference 'User.count' do
      with_settings :gravatar_enabled => '1' do
        put :update, :params => {
          :id => 2,
          :user => {:mail => ''}
        }
      end
    end
    assert_response :success
    assert_select_error /Email cannot be blank/
  end

  def test_destroy
    assert_difference 'User.count', -1 do
      delete :destroy, :params => {:id => 2, :confirm => User.find(2).login}
    end
    assert_redirected_to '/users'
    assert_nil User.find_by_id(2)
  end

  def test_destroy_with_lock_param_should_lock_instead
    assert_no_difference 'User.count' do
      delete :destroy, :params => {:id => 2, :lock => 'lock'}
    end
    assert_redirected_to '/users'
    assert User.find_by_id(2).locked?
  end

  def test_destroy_should_require_confirmation
    assert_no_difference 'User.count' do
      delete :destroy, :params => {:id => 2}
    end
    assert_response :success
    assert_select '.warning', :text => /Are you sure you want to delete this user/
  end

  def test_destroy_should_require_correct_confirmation
    assert_no_difference 'User.count' do
      delete :destroy, :params => {:id => 2, :confirm => 'wrong'}
    end
    assert_response :success
    assert_select '.warning', :text => /Are you sure you want to delete this user/
  end

  def test_destroy_should_be_denied_for_non_admin_users
    @request.session[:user_id] = 3

    assert_no_difference 'User.count' do
      delete :destroy, :params => {:id => 2, :confirm => User.find(2).login}
    end
    assert_response :forbidden
  end

  def test_destroy_should_be_denied_for_anonymous
    assert User.find(6).anonymous?
    assert_no_difference 'User.count' do
      delete :destroy, :params => {:id => 6, :confirm => User.find(6).login}
    end
    assert_response :not_found
  end

  def test_destroy_should_redirect_to_back_url_param
    assert_difference 'User.count', -1 do
      delete :destroy, :params => {:id => 2,
                                   :confirm => User.find(2).login,
                                   :back_url => '/users?name=foo'}
    end
    assert_redirected_to '/users?name=foo'
  end

  def test_destroy_active_admin_should_send_security_notification
    user = User.find(2)
    user.admin = true
    user.save!
    ActionMailer::Base.deliveries.clear
    delete :destroy, :params => {:id => user.id, :confirm => user.login}

    assert_not_nil (mail = ActionMailer::Base.deliveries.last)
    assert_mail_body_match(
      I18n.t(
        :mail_body_security_notification_remove,
        field: I18n.t(:field_admin),
        value: user.login
      ),
      mail
    )
    # All admins should receive this
    User.where(admin: true, status: Principal::STATUS_ACTIVE).each do |admin|
      assert_not_nil(
        ActionMailer::Base.deliveries.detect do |mail|
          [mail.to].flatten.include?(admin.mail)
        end
      )
    end
  end

  def test_destroy_without_unsubscribe_is_denied
    user = User.find(2)
    user.update(admin: true) # Create other admin so self can be deleted
    @request.session[:user_id] = user.id
    with_settings unsubscribe: 0 do
      assert_no_difference 'User.count' do
        delete :destroy, params: {id: user.id}
      end
      assert_response :unprocessable_content
    end
  end

  def test_destroy_last_admin_is_denied
    user = User.find(1)
    @request.session[:user_id] = user.id
    with_settings unsubscribe: 1 do
      assert_no_difference 'User.count' do
        delete :destroy, params: {id: user.id}
      end
      assert_response :unprocessable_content
    end
  end

  def test_bulk_destroy
    assert_difference 'User.count', -1 do
      delete :bulk_destroy, :params => {:ids => [2], :confirm => 'Yes'}
    end
    assert_redirected_to '/users'
    assert_nil User.find_by_id(2)
  end

  def test_bulk_destroy_should_not_destroy_current_user
    assert_difference 'User.count', -1 do
      delete :bulk_destroy, :params => {:ids => [2, 1], :confirm => 'Yes'}
    end
    assert_redirected_to '/users'
    assert_nil User.find_by_id(2)
  end

  def test_bulk_destroy_should_require_confirmation
    assert_no_difference 'User.count' do
      delete :bulk_destroy, :params => {:ids => [2]}
    end
    assert_response :success
    assert_select '.warning', :text => /You are about to delete the following users/
  end

  def test_bulk_destroy_should_require_correct_confirmation
    assert_no_difference 'User.count' do
      delete :bulk_destroy, :params => {:ids => [2], :confirm => 'wrong'}
    end
    assert_response :success
    assert_select '.warning', :text => /You are about to delete the following users/
  end

  def test_bulk_destroy_should_be_denied_for_non_admin_users
    @request.session[:user_id] = 3

    assert_no_difference 'User.count' do
      delete :bulk_destroy, :params => {:ids => [2], :confirm => 'Yes'}
    end
    assert_response :forbidden
  end

  def test_bulk_destroy_should_be_denied_for_anonymous
    assert User.find(6).anonymous?
    assert_no_difference 'User.count' do
      delete :bulk_destroy, :params => {:ids => [6], :confirm => "Yes"}
    end
    assert_response :not_found
  end

  def test_bulk_lock
    assert_difference 'User.status(User::STATUS_LOCKED).count', 1 do
      delete :bulk_lock, :params => {:ids => [2]}
    end
    assert_redirected_to '/users'
    assert User.find_by_id(2).locked?
  end

  def test_bulk_unlock
    [8, 9].each do |id|
      user = User.find(id)
      user.status = User::STATUS_LOCKED
      user.save!
    end

    assert_difference 'User.status(User::STATUS_LOCKED).count', -2 do
      post :bulk_unlock, :params => {:ids => [8, 9]}
    end

    assert_redirected_to '/users'
    assert User.find_by_id(8).active?
    assert User.find_by_id(9).active?
  end

  def test_bulk_lock_should_not_lock_current_user
    assert_difference 'User.status(User::STATUS_LOCKED).count', 1 do
      delete :bulk_lock, :params => {:ids => [2, 1]}
    end
    assert_redirected_to '/users'
    assert_not User.find_by_id(1).locked?
    assert User.find_by_id(2).locked?
  end

  def test_bulk_lock_should_be_denied_for_non_admin_users
    @request.session[:user_id] = 3

    assert_no_difference 'User.status(User::STATUS_LOCKED).count' do
      delete :bulk_lock, :params => {:ids => [2]}
    end
    assert_response :forbidden
  end

  def test_bulk_lock_should_be_denied_for_anonymous
    assert User.find(6).anonymous?
    assert_no_difference 'User.status(User::STATUS_LOCKED).count' do
      delete :bulk_lock, :params => {:ids => [6]}
    end
    assert_response :not_found
  end
end
