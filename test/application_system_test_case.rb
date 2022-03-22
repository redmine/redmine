# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

require File.expand_path('../test_helper', __FILE__)
require 'webdrivers/chromedriver'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  DOWNLOADS_PATH = File.expand_path(File.join(Rails.root, 'tmp', 'downloads'))
  GOOGLE_CHROME_OPTS_ARGS = []

  # Allow running Capybara default server on custom IP address and/or port
  Capybara.server_host = ENV['CAPYBARA_SERVER_HOST'] if ENV['CAPYBARA_SERVER_HOST']
  Capybara.server_port = ENV['CAPYBARA_SERVER_PORT'] if ENV['CAPYBARA_SERVER_PORT']

  # Allow defining Google Chrome options arguments based on a comma-delimited string environment variable
  GOOGLE_CHROME_OPTS_ARGS = ENV['GOOGLE_CHROME_OPTS_ARGS'].split(",") if ENV['GOOGLE_CHROME_OPTS_ARGS']

  options = {}
  # Allow running tests using a remote Selenium hub
  options[:url] = ENV['SELENIUM_REMOTE_URL'] if ENV['SELENIUM_REMOTE_URL']
  options[:desired_capabilities] = Selenium::WebDriver::Remote::Capabilities.chrome(
                  'goog:chromeOptions' => {
                    'args' => GOOGLE_CHROME_OPTS_ARGS,
                    'prefs' => {
                      'download.default_directory' => DOWNLOADS_PATH.gsub(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR),
                      'download.prompt_for_download' => false,
                      'plugins.plugins_disabled' => ["Chrome PDF Viewer"]
                    }
                  }
                )

  driven_by(
    :selenium, using: :chrome, screen_size: [1024, 900],
    options: options
  )

  setup do
    # Allow defining a custom app host (useful when using a remote Selenium hub)
    if ENV['CAPYBARA_APP_HOST']
      Capybara.configure do |config|
        config.app_host = ENV['CAPYBARA_APP_HOST']
      end
    end

    clear_downloaded_files
    Setting.delete_all
    Setting.clear_cache
  end

  teardown do
    Setting.delete_all
    Setting.clear_cache
  end

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

  def wait_for_ajax
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until page.evaluate_script("jQuery.active").zero?
    end
  end

  def clear_downloaded_files
    FileUtils.rm downloaded_files
  end

  def downloaded_files(filename='*')
    Dir.glob("#{DOWNLOADS_PATH}/#{filename}").
      reject{|f| f=~/\.(tmp|crdownload)$/}.sort_by{|f| File.mtime(f)}
  end

  # Returns the path of the download file
  def downloaded_file(filename='*')
    files = []
    Timeout.timeout(5) do
      loop do
        files = downloaded_files(filename)
        break if files.present?

        sleep 0.2
      end
    end
    files.last
  end
end

FileUtils.mkdir_p ApplicationSystemTestCase::DOWNLOADS_PATH
