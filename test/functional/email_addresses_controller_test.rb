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

class EmailAddressesControllerTest < Redmine::ControllerTest
  def setup
    User.current = nil
  end

  def test_index_with_no_additional_emails
    @request.session[:user_id] = 2
    get(:index, :params => {:user_id => 2})
    assert_response :success
  end

  def test_index_with_additional_emails
    @request.session[:user_id] = 2
    EmailAddress.create!(:user_id => 2, :address => 'another@somenet.foo')

    get(:index, :params => {:user_id => 2})
    assert_response :success
    assert_select '.email', :text => 'another@somenet.foo'
  end

  def test_index_with_additional_emails_as_js
    @request.session[:user_id] = 2
    EmailAddress.create!(:user_id => 2, :address => 'another@somenet.foo')

    get(:index, :params => {:user_id => 2}, :xhr => true)
    assert_response :success
    assert_include 'another@somenet.foo', response.body
  end

  def test_index_by_admin_should_be_allowed
    @request.session[:user_id] = 1
    get(:index, :params => {:user_id => 2})
    assert_response :success
  end

  def test_index_by_another_user_should_be_denied
    @request.session[:user_id] = 3
    get(:index, :params => {:user_id => 2})
    assert_response :forbidden
  end

  def test_create
    @request.session[:user_id] = 2
    assert_difference 'EmailAddress.count' do
      post(
        :create,
        :params => {
          :user_id => 2,
          :email_address => {
            :address => 'another@somenet.foo'
          }
        }
      )
      assert_response :found
      assert_redirected_to '/users/2/email_addresses'
    end
    email = EmailAddress.order('id DESC').first
    assert_equal 2, email.user_id
    assert_equal 'another@somenet.foo', email.address
  end

  def test_create_as_js
    @request.session[:user_id] = 2
    assert_difference 'EmailAddress.count' do
      post(
        :create,
        :params => {
          :user_id => 2,
          :email_address => {
            :address => 'another@somenet.foo'
          }
        },
        :xhr => true
      )
      assert_response :ok
    end
  end

  def test_create_with_failure
    @request.session[:user_id] = 2
    assert_no_difference 'EmailAddress.count' do
      post(
        :create,
        :params => {
          :user_id => 2,
          :email_address => {
            :address => 'invalid'
          }
        }
      )
      assert_response :success
      assert_select_error /email is invalid/i
    end
  end

  def test_create_with_disallowed_domain_should_fail
    @request.session[:user_id] = 2

    with_settings :email_domains_denied => 'black.example' do
      assert_no_difference 'EmailAddress.count' do
        post(
          :create,
          :params => {
            :user_id => 2,
            :email_address => {
              :address => 'another@black.example'
            }
          }
        )
        assert_response :success
        assert_select_error 'Email contains a domain not allowed (black.example)'
      end
    end

    with_settings :email_domains_allowed => 'white.example' do
      assert_no_difference 'EmailAddress.count' do
        post(
          :create,
          :params => {
            :user_id => 2,
            :email_address => {
              :address => 'something@example.fr'
            }
          }
        )
        assert_response :success
        assert_select_error 'Email contains a domain not allowed (example.fr)'
      end
    end
  end

  def test_create_should_send_security_notification
    @request.session[:user_id] = 2
    ActionMailer::Base.deliveries.clear
    post(
      :create,
      :params => {
        :user_id => 2,
        :email_address => {
          :address => 'something@example.fr'
        }
      }
    )
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_mail_body_match '0.0.0.0', mail
    assert_mail_body_match I18n.t(:mail_body_security_notification_add, field: I18n.t(:field_mail), value: 'something@example.fr'), mail
    assert_select_email do
      assert_select 'a[href^=?]', 'http://localhost:3000/my/account', :text => 'My account'
    end
    # The old email address should be notified about a new address for security purposes
    assert mail.to.include?(User.find(2).mail)
    assert mail.to.include?('something@example.fr')
  end

  def test_update
    @request.session[:user_id] = 2
    email = EmailAddress.create!(:user_id => 2, :address => 'another@somenet.foo')

    put(
      :update,
      :params => {
        :user_id => 2,
        :id => email.id,
        :notify => '0'
      }
    )
    assert_response :found

    assert_equal false, email.reload.notify
  end

  def test_update_as_js
    @request.session[:user_id] = 2
    email = EmailAddress.create!(:user_id => 2, :address => 'another@somenet.foo')

    put(
      :update,
      :params => {
        :user_id => 2,
        :id => email.id,
        :notify => '0'
      },
      :xhr => true
    )
    assert_response :ok

    assert_equal false, email.reload.notify
  end

  def test_update_should_send_security_notification
    @request.session[:user_id] = 2
    email = EmailAddress.create!(:user_id => 2, :address => 'another@somenet.foo')

    ActionMailer::Base.deliveries.clear
    put(
      :update,
      :params => {
        :user_id => 2,
        :id => email.id,
        :notify => '0'
      },
      :xhr => true
    )
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_mail_body_match I18n.t(:mail_body_security_notification_notify_disabled, value: 'another@somenet.foo'), mail

    # The changed address should be notified for security purposes
    assert mail.to.include?('another@somenet.foo')
  end

  def test_destroy
    @request.session[:user_id] = 2
    email = EmailAddress.create!(:user_id => 2, :address => 'another@somenet.foo')

    assert_difference 'EmailAddress.count', -1 do
      delete(
        :destroy,
        :params => {
          :user_id => 2,
          :id => email.id
        }
      )
      assert_response :found
      assert_redirected_to '/users/2/email_addresses'
    end
  end

  def test_destroy_as_js
    @request.session[:user_id] = 2
    email = EmailAddress.create!(:user_id => 2, :address => 'another@somenet.foo')

    assert_difference 'EmailAddress.count', -1 do
      delete(
        :destroy,
        :params => {
          :user_id => 2,
          :id => email.id
        },
        :xhr => true
      )
      assert_response :ok
    end
  end

  def test_should_not_destroy_default
    @request.session[:user_id] = 2

    assert_no_difference 'EmailAddress.count' do
      delete(
        :destroy,
        :params => {
          :user_id => 2,
          :id => User.find(2).email_address.id
        }
      )
      assert_response :not_found
    end
  end

  def test_destroy_should_send_security_notification
    @request.session[:user_id] = 2
    email = EmailAddress.create!(:user_id => 2, :address => 'another@somenet.foo')

    ActionMailer::Base.deliveries.clear
    delete(
      :destroy,
      :params => {
        :user_id => 2,
        :id => email.id
      },
      :xhr => true
    )
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_mail_body_match I18n.t(:mail_body_security_notification_remove, field: I18n.t(:field_mail), value: 'another@somenet.foo'), mail

    # The removed address should be notified for security purposes
    assert mail.to.include?('another@somenet.foo')
  end
end
