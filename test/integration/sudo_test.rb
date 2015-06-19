require File.expand_path('../../test_helper', __FILE__)

class SudoTest < Redmine::IntegrationTest
  fixtures :projects, :members, :member_roles, :roles, :users

  def setup
    Redmine::SudoMode.enable!
  end

  def teardown
    Redmine::SudoMode.disable!
  end

  def test_create_member_xhr
    log_user 'admin', 'admin'
    get '/projects/ecookbook/settings/members'
    assert_response :success

    assert_no_difference 'Member.count' do
      xhr :post, '/projects/ecookbook/memberships', membership: {role_ids: [1], user_id: 7}
    end

    assert_no_difference 'Member.count' do
      xhr :post, '/projects/ecookbook/memberships', membership: {role_ids: [1], user_id: 7}, sudo_password: ''
    end

    assert_no_difference 'Member.count' do
      xhr :post, '/projects/ecookbook/memberships', membership: {role_ids: [1], user_id: 7}, sudo_password: 'wrong'
    end

    assert_difference 'Member.count' do
      xhr :post, '/projects/ecookbook/memberships', membership: {role_ids: [1], user_id: 7}, sudo_password: 'admin'
    end
    assert User.find(7).member_of?(Project.find(1))
  end

  def test_create_member
    log_user 'admin', 'admin'
    get '/projects/ecookbook/settings/members'
    assert_response :success

    assert_no_difference 'Member.count' do
      post '/projects/ecookbook/memberships', membership: {role_ids: [1], user_id: 7}
    end

    assert_no_difference 'Member.count' do
      post '/projects/ecookbook/memberships', membership: {role_ids: [1], user_id: 7}, sudo_password: ''
    end

    assert_no_difference 'Member.count' do
      post '/projects/ecookbook/memberships', membership: {role_ids: [1], user_id: 7}, sudo_password: 'wrong'
    end

    assert_difference 'Member.count' do
      post '/projects/ecookbook/memberships', membership: {role_ids: [1], user_id: 7}, sudo_password: 'admin'
    end

    assert_redirected_to '/projects/ecookbook/settings/members'
    assert User.find(7).member_of?(Project.find(1))
  end

  def test_create_role
    log_user 'admin', 'admin'
    get '/roles'
    assert_response :success

    get '/roles/new'
    assert_response :success

    post '/roles', role: { }
    assert_response :success
    assert_select 'h2', 'Confirm your password to continue'
    assert_select 'form[action="/roles"]'
    assert assigns(:sudo_form).errors.blank?

    post '/roles', role: { name: 'new role', issues_visibility: 'all' }
    assert_response :success
    assert_select 'h2', 'Confirm your password to continue'
    assert_select 'form[action="/roles"]'
    assert_match /"new role"/, response.body
    assert assigns(:sudo_form).errors.blank?

    post '/roles', role: { name: 'new role', issues_visibility: 'all' }, sudo_password: 'wrong'
    assert_response :success
    assert_select 'h2', 'Confirm your password to continue'
    assert_select 'form[action="/roles"]'
    assert_match /"new role"/, response.body
    assert assigns(:sudo_form).errors[:password].present?

    assert_difference 'Role.count' do
      post '/roles', role: { name: 'new role', issues_visibility: 'all', assignable: '1', permissions: %w(view_calendar) }, sudo_password: 'admin'
    end
    assert_redirected_to '/roles'
  end

  def test_update_email_address
    log_user 'jsmith', 'jsmith'
    get '/my/account'
    assert_response :success
    post '/my/account', user: { mail: 'newmail@test.com' }
    assert_response :success
    assert_select 'h2', 'Confirm your password to continue'
    assert_select 'form[action="/my/account"]'
    assert_match /"newmail@test\.com"/, response.body
    assert assigns(:sudo_form).errors.blank?

    # wrong password
    post '/my/account', user: { mail: 'newmail@test.com' }, sudo_password: 'wrong'
    assert_response :success
    assert_select 'h2', 'Confirm your password to continue'
    assert_select 'form[action="/my/account"]'
    assert_match /"newmail@test\.com"/, response.body
    assert assigns(:sudo_form).errors[:password].present?

    # correct password
    post '/my/account', user: { mail: 'newmail@test.com' }, sudo_password: 'jsmith'
    assert_redirected_to '/my/account'
    assert_equal 'newmail@test.com', User.find_by_login('jsmith').mail

    # sudo mode should now be active and not require password again
    post '/my/account', user: { mail: 'even.newer.mail@test.com' }
    assert_redirected_to '/my/account'
    assert_equal 'even.newer.mail@test.com', User.find_by_login('jsmith').mail
  end

end
