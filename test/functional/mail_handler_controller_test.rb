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

class MailHandlerControllerTest < Redmine::ControllerTest
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures/mail_handler'

  def setup
    User.current = nil
  end

  def test_should_create_issue
    # Enable API and set a key
    with_settings(
      :mail_handler_api_enabled => 1,
      :mail_handler_api_key => 'secret'
    ) do
      assert_difference 'Issue.count' do
        post(
          :index,
          :params => {
            :key => 'secret',
            :email =>
               IO.read(
                 File.join(FIXTURES_PATH, 'ticket_on_given_project.eml')
               )
          }
        )
      end
    end
    assert_response :created
  end

  def test_should_create_issue_with_options
    # Enable API and set a key
    with_settings(
      :mail_handler_api_enabled => 1,
      :mail_handler_api_key => 'secret'
    ) do
      assert_difference 'Issue.count' do
        post(
          :index,
          :params => {
            :key => 'secret',
            :email =>
              IO.read(
                File.join(FIXTURES_PATH, 'ticket_on_given_project.eml')
              ),
            :issue => {
              :is_private => '1'
            }
          }
        )
      end
    end
    assert_response :created
    issue = Issue.order(:id => :desc).first
    assert_equal true, issue.is_private
  end

  def test_should_update_issue
    # Enable API and set a key
    with_settings(
      :mail_handler_api_enabled => 1,
      :mail_handler_api_key => 'secret'
    ) do
      assert_no_difference 'Issue.count' do
        assert_difference 'Journal.count' do
          post(
            :index,
            :params => {
              :key => 'secret',
              :email => IO.read(File.join(FIXTURES_PATH, 'ticket_reply.eml'))
            }
          )
        end
      end
    end
    assert_response :created
  end

  def test_should_respond_with_422_if_not_created
    Project.find('onlinestore').destroy
    with_settings(
      :mail_handler_api_enabled => 1,
      :mail_handler_api_key => 'secret'
    ) do
      assert_no_difference 'Issue.count' do
        post(
          :index,
          :params => {
            :key => 'secret',
            :email =>
              IO.read(File.join(FIXTURES_PATH, 'ticket_on_given_project.eml'))
          }
        )
      end
    end
    assert_response :unprocessable_content
  end

  def test_should_not_allow_with_api_disabled
    # Disable API
    with_settings(
      :mail_handler_api_enabled => 0,
      :mail_handler_api_key => 'secret'
    ) do
      assert_no_difference 'Issue.count' do
        post(
          :index,
          :params => {
            :key => 'secret',
            :email =>
              IO.read(File.join(FIXTURES_PATH, 'ticket_on_given_project.eml'))
          }
        )
      end
    end
    assert_response :forbidden
    assert_include 'Access denied', response.body
  end

  def test_should_not_allow_with_wrong_key
    with_settings(
      :mail_handler_api_enabled => 1,
      :mail_handler_api_key => 'secret'
    ) do
      assert_no_difference 'Issue.count' do
        post(
          :index,
          :params => {
            :key => 'wrong',
            :email =>
              IO.read(File.join(FIXTURES_PATH, 'ticket_on_given_project.eml'))
          }
        )
      end
    end
    assert_response :forbidden
    assert_include 'Access denied', response.body
  end

  def test_new
    with_settings(
      :mail_handler_api_enabled => 1,
      :mail_handler_api_key => 'secret'
    ) do
      get(:new, :params => {:key => 'secret'})
    end
    assert_response :success
  end

  def test_should_skip_verify_authenticity_token
    ActionController::Base.allow_forgery_protection = true
    assert_nothing_raised {test_should_create_issue}
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
end
