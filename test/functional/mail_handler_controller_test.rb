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

class MailHandlerControllerTest < Redmine::ControllerTest
  fixtures :users, :email_addresses, :projects, :enabled_modules, :roles, :members, :member_roles, :issues, :issue_statuses,
           :trackers, :projects_trackers, :enumerations

  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures/mail_handler'

  def setup
    User.current = nil
  end

  def test_should_create_issue
    # Enable API and set a key
    Setting.mail_handler_api_enabled = 1
    Setting.mail_handler_api_key = 'secret'

    assert_difference 'Issue.count' do
      post :index, :params => {
          :key => 'secret',
          :email => IO.read(File.join(FIXTURES_PATH, 'ticket_on_given_project.eml'))
        }
    end
    assert_response 201
  end

  def test_should_create_issue_with_options
    # Enable API and set a key
    Setting.mail_handler_api_enabled = 1
    Setting.mail_handler_api_key = 'secret'

    assert_difference 'Issue.count' do
      post :index, :params => {
          :key => 'secret',
          :email => IO.read(File.join(FIXTURES_PATH, 'ticket_on_given_project.eml')),
          :issue => {
            :is_private => '1'
          }
        }
    end
    assert_response 201
    issue = Issue.order(:id => :desc).first
    assert_equal true, issue.is_private
  end

  def test_should_update_issue
    # Enable API and set a key
    Setting.mail_handler_api_enabled = 1
    Setting.mail_handler_api_key = 'secret'

    assert_no_difference 'Issue.count' do
      assert_difference 'Journal.count' do
        post :index, :params => {
            :key => 'secret',
            :email => IO.read(File.join(FIXTURES_PATH, 'ticket_reply.eml'))
          }
      end
    end
    assert_response 201
  end

  def test_should_respond_with_422_if_not_created
    Project.find('onlinestore').destroy

    Setting.mail_handler_api_enabled = 1
    Setting.mail_handler_api_key = 'secret'

    assert_no_difference 'Issue.count' do
      post :index, :params => {
          :key => 'secret',
          :email => IO.read(File.join(FIXTURES_PATH, 'ticket_on_given_project.eml'))
        }
    end
    assert_response 422
  end

  def test_should_not_allow_with_api_disabled
    # Disable API
    Setting.mail_handler_api_enabled = 0
    Setting.mail_handler_api_key = 'secret'

    assert_no_difference 'Issue.count' do
      post :index, :params => {
          :key => 'secret',
          :email => IO.read(File.join(FIXTURES_PATH, 'ticket_on_given_project.eml'))
        }
    end
    assert_response 403
    assert_include 'Access denied', response.body
  end

  def test_should_not_allow_with_wrong_key
    Setting.mail_handler_api_enabled = 1
    Setting.mail_handler_api_key = 'secret'

    assert_no_difference 'Issue.count' do
      post :index, :params => {
          :key => 'wrong',
          :email => IO.read(File.join(FIXTURES_PATH, 'ticket_on_given_project.eml'))
        }
    end
    assert_response 403
    assert_include 'Access denied', response.body
  end

  def test_new
    Setting.mail_handler_api_enabled = 1
    Setting.mail_handler_api_key = 'secret'

    get :new, :params => {
        :key => 'secret'
      }
    assert_response :success
  end
end
