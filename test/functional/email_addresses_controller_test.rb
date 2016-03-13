# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class EmailAddressesControllerTest < ActionController::TestCase
  fixtures :users, :email_addresses

  def setup
    User.current = nil
  end

  def test_index_with_no_additional_emails
    @request.session[:user_id] = 2
    get :index, :user_id => 2
    assert_response :success
    assert_template 'index'
  end

  def test_index_with_additional_emails
    @request.session[:user_id] = 2
    EmailAddress.create!(:user_id => 2, :address => 'another@somenet.foo')

    get :index, :user_id => 2
    assert_response :success
    assert_template 'index'
    assert_select '.email', :text => 'another@somenet.foo'
  end

  def test_index_with_additional_emails_as_js
    @request.session[:user_id] = 2
    EmailAddress.create!(:user_id => 2, :address => 'another@somenet.foo')

    xhr :get, :index, :user_id => 2
    assert_response :success
    assert_template 'index'
    assert_include 'another@somenet.foo', response.body
  end

  def test_index_by_admin_should_be_allowed
    @request.session[:user_id] = 1
    get :index, :user_id => 2
    assert_response :success
    assert_template 'index'
  end

  def test_index_by_another_user_should_be_denied
    @request.session[:user_id] = 3
    get :index, :user_id => 2
    assert_response 403
  end

  def test_create
    @request.session[:user_id] = 2
    assert_difference 'EmailAddress.count' do
      post :create, :user_id => 2, :email_address => {:address => 'another@somenet.foo'}
      assert_response 302
      assert_redirected_to '/users/2/email_addresses'
    end
    email = EmailAddress.order('id DESC').first
    assert_equal 2, email.user_id
    assert_equal 'another@somenet.foo', email.address
  end

  def test_create_as_js
    @request.session[:user_id] = 2
    assert_difference 'EmailAddress.count' do
      xhr :post, :create, :user_id => 2, :email_address => {:address => 'another@somenet.foo'}
      assert_response 200
    end
  end

  def test_create_with_failure
    @request.session[:user_id] = 2
    assert_no_difference 'EmailAddress.count' do
      post :create, :user_id => 2, :email_address => {:address => 'invalid'}
      assert_response 200
    end
  end

  def test_create_should_send_security_notification
    @request.session[:user_id] = 2
    ActionMailer::Base.deliveries.clear
    post :create, :user_id => 2, :email_address => {:address => 'something@example.fr'}

    assert_not_nil (mail = ActionMailer::Base.deliveries.last)
    assert_mail_body_match '0.0.0.0', mail
    assert_mail_body_match I18n.t(:mail_body_security_notification_add, field: I18n.t(:field_mail), value: 'something@example.fr'), mail
    assert_select_email do
      assert_select 'a[href^=?]', 'http://localhost:3000/my/account', :text => 'My account'
    end
    # The old email address should be notified about a new address for security purposes
    assert [mail.bcc, mail.cc].flatten.include?(User.find(2).mail)
    assert [mail.bcc, mail.cc].flatten.include?('something@example.fr')
  end

  def test_update
    @request.session[:user_id] = 2
    email = EmailAddress.create!(:user_id => 2, :address => 'another@somenet.foo')

    put :update, :user_id => 2, :id => email.id, :notify => '0'
    assert_response 302

    assert_equal false, email.reload.notify
  end

  def test_update_as_js
    @request.session[:user_id] = 2
    email = EmailAddress.create!(:user_id => 2, :address => 'another@somenet.foo')

    xhr :put, :update, :user_id => 2, :id => email.id, :notify => '0'
    assert_response 200

    assert_equal false, email.reload.notify
  end

  def test_update_should_send_security_notification
    @request.session[:user_id] = 2
    email = EmailAddress.create!(:user_id => 2, :address => 'another@somenet.foo')

    ActionMailer::Base.deliveries.clear
    xhr :put, :update, :user_id => 2, :id => email.id, :notify => '0'

    assert_not_nil (mail = ActionMailer::Base.deliveries.last)
    assert_mail_body_match I18n.t(:mail_body_security_notification_notify_disabled, value: 'another@somenet.foo'), mail

    # The changed address should be notified for security purposes
    assert [mail.bcc, mail.cc].flatten.include?('another@somenet.foo')
  end


  def test_destroy
    @request.session[:user_id] = 2
    email = EmailAddress.create!(:user_id => 2, :address => 'another@somenet.foo')

    assert_difference 'EmailAddress.count', -1 do
      delete :destroy, :user_id => 2, :id => email.id
      assert_response 302
      assert_redirected_to '/users/2/email_addresses'
    end
  end

  def test_destroy_as_js
    @request.session[:user_id] = 2
    email = EmailAddress.create!(:user_id => 2, :address => 'another@somenet.foo')

    assert_difference 'EmailAddress.count', -1 do
      xhr :delete, :destroy, :user_id => 2, :id => email.id
      assert_response 200
    end
  end

  def test_should_not_destroy_default
    @request.session[:user_id] = 2

    assert_no_difference 'EmailAddress.count' do
      delete :destroy, :user_id => 2, :id => User.find(2).email_address.id
      assert_response 404
    end
  end

  def test_destroy_should_send_security_notification
    @request.session[:user_id] = 2
    email = EmailAddress.create!(:user_id => 2, :address => 'another@somenet.foo')

    ActionMailer::Base.deliveries.clear
    xhr :delete, :destroy, :user_id => 2, :id => email.id

    assert_not_nil (mail = ActionMailer::Base.deliveries.last)
    assert_mail_body_match I18n.t(:mail_body_security_notification_remove, field: I18n.t(:field_mail), value: 'another@somenet.foo'), mail

    # The removed address should be notified for security purposes
    assert [mail.bcc, mail.cc].flatten.include?('another@somenet.foo')
  end
end
