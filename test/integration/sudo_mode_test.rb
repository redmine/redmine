# frozen_string_literal: true

require File.expand_path('../../test_helper', __FILE__)

class SudoModeTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :users, :email_addresses

  def setup
    Redmine::SudoMode.stubs(:enabled?).returns(true)
  end

  def teardown
    travel_back
  end

  def test_sudo_mode_should_be_active_after_login
    log_user("admin", "admin")
    get "/users/new"
    assert_response :success
    post(
      "/users",
      :params => {
        :user => {
          :login => "psmith", :firstname => "Paul",
          :lastname => "Smith", :mail => "psmith@somenet.foo",
          :language => "en", :password => "psmith09",
          :password_confirmation => "psmith09"
        }
      }
    )
    assert_response 302

    user = User.find_by_login("psmith")
    assert_kind_of User, user
  end

  def test_add_user
    log_user("admin", "admin")
    expire_sudo_mode!
    get "/users/new"
    assert_response :success
    post(
      "/users",
      :params => {
        :user => {
          :login => "psmith", :firstname => "Paul",
          :lastname => "Smith", :mail => "psmith@somenet.foo",
          :language => "en", :password => "psmith09",
          :password_confirmation => "psmith09"
        }
      }
    )
    assert_response :success
    assert_nil User.find_by_login("psmith")

    assert_select 'input[name=?][value=?]', 'user[login]', 'psmith'
    assert_select 'input[name=?][value=?]', 'user[firstname]', 'Paul'

    post(
      "/users",
      :params => {
        :user => {
          :login => "psmith", :firstname => "Paul",
          :lastname => "Smith", :mail => "psmith@somenet.foo",
          :language => "en", :password => "psmith09",
          :password_confirmation => "psmith09"
        },
        :sudo_password => 'admin'
      }
    )
    assert_response 302

    user = User.find_by_login("psmith")
    assert_kind_of User, user
  end

  def test_create_member_xhr
    log_user 'admin', 'admin'
    expire_sudo_mode!
    get '/projects/ecookbook/settings/members'
    assert_response :success

    assert_no_difference 'Member.count' do
      post '/projects/ecookbook/memberships', :params => {membership: {role_ids: [1], user_id: 7}}, :xhr => true
    end

    assert_no_difference 'Member.count' do
      post '/projects/ecookbook/memberships', :params => {membership: {role_ids: [1], user_id: 7}, sudo_password: ''}, :xhr => true
    end

    assert_no_difference 'Member.count' do
      post '/projects/ecookbook/memberships', :params => {membership: {role_ids: [1], user_id: 7}, sudo_password: 'wrong'}, :xhr => true
    end

    assert_difference 'Member.count' do
      post '/projects/ecookbook/memberships', :params => {membership: {role_ids: [1], user_id: 7}, sudo_password: 'admin'}, :xhr => true
    end
    assert User.find(7).member_of?(Project.find(1))
  end

  def test_create_member
    log_user 'admin', 'admin'
    expire_sudo_mode!
    get '/projects/ecookbook/settings/members'
    assert_response :success

    assert_no_difference 'Member.count' do
      post '/projects/ecookbook/memberships', :params => {membership: {role_ids: [1], user_id: 7}}
    end

    assert_no_difference 'Member.count' do
      post '/projects/ecookbook/memberships', :params => {membership: {role_ids: [1], user_id: 7}, sudo_password: ''}
    end

    assert_no_difference 'Member.count' do
      post '/projects/ecookbook/memberships', :params => {membership: {role_ids: [1], user_id: 7}, sudo_password: 'wrong'}
    end

    assert_difference 'Member.count' do
      post '/projects/ecookbook/memberships', :params => {membership: {role_ids: [1], user_id: 7}, sudo_password: 'admin'}
    end

    assert_redirected_to '/projects/ecookbook/settings/members'
    assert User.find(7).member_of?(Project.find(1))
  end

  def test_create_role
    log_user 'admin', 'admin'
    expire_sudo_mode!
    get '/roles'
    assert_response :success

    get '/roles/new'
    assert_response :success

    post('/roles', :params => {:role => {}})
    assert_response :success
    assert_select 'h2', 'Confirm your password to continue'
    assert_select 'form[action="/roles"]'
    assert_select '#flash_error', 0

    post(
      '/roles',
      :params => {
        :role => {
          :name => 'new role',
          :issues_visibility => 'all'
        }
      }
    )
    assert_response :success
    assert_select 'h2', 'Confirm your password to continue'
    assert_select 'form[action="/roles"]'
    assert_select 'input[type=hidden][name=?][value=?]', 'role[name]', 'new role'
    assert_select '#flash_error', 0

    post(
      '/roles',
      :params => {
        :role => {
          :name => 'new role',
          :issues_visibility => 'all'
        },
        :sudo_password => 'wrong'
      }
    )
    assert_response :success
    assert_select 'h2', 'Confirm your password to continue'
    assert_select 'form[action="/roles"]'
    assert_select 'input[type=hidden][name=?][value=?]', 'role[name]', 'new role'
    assert_select '#flash_error'

    assert_difference 'Role.count' do
      post(
        '/roles',
        :params => {
          :role => {
            :name => 'new role',
            :issues_visibility => 'all',
            :assignable => '1',
            :permissions => %w(view_calendar)
          },
          :sudo_password => 'admin'
        }
      )
    end
    assert_redirected_to '/roles'
  end

  def test_update_email_address
    log_user 'jsmith', 'jsmith'
    expire_sudo_mode!
    get '/my/account'
    assert_response :success
    put('/my/account', :params => {:user => {:mail => 'newmail@test.com'}})
    assert_response :success
    assert_select 'h2', 'Confirm your password to continue'
    assert_select 'form[action="/my/account"]'
    assert_select 'input[type=hidden][name=?][value=?]', 'user[mail]', 'newmail@test.com'
    assert_select '#flash_error', 0

    # wrong password
    put(
      '/my/account',
      :params => {
        :user => {
          :mail => 'newmail@test.com'
        },
        :sudo_password => 'wrong'
      }
    )
    assert_response :success
    assert_select 'h2', 'Confirm your password to continue'
    assert_select 'form[action="/my/account"]'
    assert_select 'input[type=hidden][name=?][value=?]', 'user[mail]', 'newmail@test.com'
    assert_select '#flash_error'

    # correct password
    put(
      '/my/account',
      :params => {
        :user => {
          :mail => 'newmail@test.com'
        },
        :sudo_password => 'jsmith'
      }
    )
    assert_redirected_to '/my/account'
    assert_equal 'newmail@test.com', User.find_by_login('jsmith').mail

    # sudo mode should now be active and not require password again
    put(
      '/my/account',
      :params => {
        :user => {
          :mail => 'even.newer.mail@test.com'
        }
      }
    )
    assert_redirected_to '/my/account'
    assert_equal 'even.newer.mail@test.com', User.find_by_login('jsmith').mail
  end

  def test_sudo_mode_should_skip_api_requests
    with_settings :rest_api_enabled => '1' do
      assert_difference('User.count') do
        post(
          '/users.json',
          :params => {
            :user => {
              :login => 'foo', :firstname => 'Firstname',
              :lastname => 'Lastname',
              :mail => 'foo@example.net', :password => 'secret123',
              :mail_notification => 'only_assigned'
            }
          },
          :headers => credentials('admin')
        )
        assert_response :created
      end
    end
  end

  private

  # sudo mode is active after sign, let it expire by advancing the time
  def expire_sudo_mode!
    travel_to 20.minutes.from_now
  end
end
