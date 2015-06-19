# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

require File.expand_path('../base', __FILE__)

class Redmine::UiTest::SudoModeTest < Redmine::UiTest::Base
  fixtures :users, :email_addresses

  def setup
    Redmine::SudoMode.stubs(:enabled?).returns(true)
  end

  def test_add_user
    log_user('admin', 'admin')
    visit '/users/new'

    assert_difference 'User.count' do
      within('form#new_user') do
        fill_in 'Login', :with => 'johnpaul'
        fill_in 'First name', :with => 'John'
        fill_in 'Last name', :with => 'Paul'
        fill_in 'Email', :with => 'john@example.net'
        fill_in 'Password', :with => 'password'
        fill_in 'Confirmation', :with => 'password'
        # click_button 'Create' would match both 'Create' and 'Create and continue' buttons
        find('input[name=commit]').click
      end

      assert_equal '/users', current_path
      assert page.has_content?("Confirm your password to continue")
      assert page.has_css?('form#sudo-form')

      within('form#sudo-form') do
        fill_in 'Password', :with => 'admin'
        click_button 'Submit'
      end
    end
  end
end
