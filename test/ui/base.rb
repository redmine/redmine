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
require 'capybara/rails'

Capybara.default_driver = :selenium
Capybara.register_driver :selenium do |app|
  # Use the following driver definition to test locally using Chrome
  # (also requires chromedriver to be in PATH)
  # Capybara::Selenium::Driver.new(app, :browser => :chrome)
  # Add :switches => %w[--lang=en] to force default browser locale to English
  # Default for Selenium remote driver is to connect to local host on port 4444 
  # This can be change using :url => 'http://localhost:9195' if necessary
  # PhantomJS 1.8 now directly supports Webdriver Wire API,
  # simply run it with `phantomjs --webdriver 4444`
  # Add :desired_capabilities => Selenium::WebDriver::Remote::Capabilities.internet_explorer)
  # to run on Selenium Grid Hub with IE
  Capybara::Selenium::Driver.new(app, :browser => :remote)
end

# default: 2
Capybara.default_wait_time = 20

DatabaseCleaner.strategy = :truncation

module Redmine
  module UiTest
    # Base class for UI tests
    class Base < ActionDispatch::IntegrationTest
      include Capybara::DSL

      # Stop ActiveRecord from wrapping tests in transactions
      # Transactional fixtures do not work with Selenium tests, because Capybara
      # uses a separate server thread, which the transactions would be hidden
      self.use_transactional_fixtures = false

      # Should not depend on locale since Redmine displays login page
      # using default browser locale which depend on system locale for "real" browsers drivers
      def log_user(login, password)
        visit '/my/page'
        assert_equal '/login', current_path
        within('#login-form form') do
          fill_in 'username', :with => login
          fill_in 'password', :with => password
          find('input[name=login]').click
        end
        assert_equal '/my/page', current_path
      end

      teardown do
        Capybara.reset_sessions!    # Forget the (simulated) browser state
        Capybara.use_default_driver # Revert Capybara.current_driver to Capybara.default_driver
        DatabaseCleaner.clean
      end
    end
  end
end
