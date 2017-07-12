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
require 'capybara/rails'
require 'fileutils'
require 'timeout'

module Redmine
  module UiTest
    module Downloads
      DOWNLOADS_PATH = File.expand_path(File.join(Rails.root, 'tmp', 'downloads'))

      def clear_downloaded_files
        FileUtils.rm downloaded_files
      end

      def downloaded_files
        Dir.glob("#{DOWNLOADS_PATH}/*").reject {|f| f=~/crdownload$/}
      end

      def downloaded_file
        Timeout.timeout(5) do
          while downloaded_files.empty?
            sleep 0.2
          end
        end
        downloaded_files.first
      end
    end
  end
end

FileUtils.mkdir_p Redmine::UiTest::Downloads::DOWNLOADS_PATH

Capybara.register_driver :chrome do |app|
  Capybara::Selenium::Driver.new(app,
      :browser => :chrome,
      :desired_capabilities => Selenium::WebDriver::Remote::Capabilities.chrome(
        'chromeOptions' => {
          'args' => [ "--window-size=1024,900" ],
          'prefs' => {
            'download.default_directory' => Redmine::UiTest::Downloads::DOWNLOADS_PATH,
            'download.prompt_for_download' => false,
            'plugins.plugins_disabled' => ["Chrome PDF Viewer"]
          }
        }
      )
    )
end
Capybara.default_driver = :chrome

# default: 2
Capybara.default_wait_time = 2

module Redmine
  module UiTest
    # Base class for UI tests
    class Base < ActionDispatch::IntegrationTest
      include Capybara::DSL
      include Redmine::UiTest::Downloads

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

      setup do
        clear_downloaded_files
        Setting.delete_all
        Setting.clear_cache
      end

      teardown do
        Capybara.reset_sessions!    # Forget the (simulated) browser state
        Capybara.use_default_driver # Revert Capybara.current_driver to Capybara.default_driver
        Setting.delete_all
        Setting.clear_cache
      end
    end
  end
end
