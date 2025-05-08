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

require_relative 'test_helper'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  DOWNLOADS_PATH = File.expand_path(File.join(Rails.root, 'tmp', 'downloads'))

  # Allow running Capybara default server on custom IP address and/or port
  Capybara.server_host = ENV['CAPYBARA_SERVER_HOST'] if ENV['CAPYBARA_SERVER_HOST']
  Capybara.server_port = ENV['CAPYBARA_SERVER_PORT'] if ENV['CAPYBARA_SERVER_PORT']

  # Allow defining Google Chrome options arguments based on a comma-delimited string environment variable
  GOOGLE_CHROME_OPTS_ARGS = ENV['GOOGLE_CHROME_OPTS_ARGS'].present? ? ENV['GOOGLE_CHROME_OPTS_ARGS'].split(",") : []

  options = {}
  if ENV['SELENIUM_REMOTE_URL']
    options[:url] = ENV['SELENIUM_REMOTE_URL']
    options[:browser] = :remote
  end

  # Allow running tests using a remote Selenium hub
  driven_by :selenium, using: :chrome, screen_size: [1024, 900], options: options do |driver_option|
    GOOGLE_CHROME_OPTS_ARGS.each do |arg|
      driver_option.add_argument arg
    end
    driver_option.add_preference 'download.default_directory',   DOWNLOADS_PATH.gsub(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR)
    driver_option.add_preference 'download.prompt_for_download', false
    driver_option.add_preference 'plugins.plugins_disabled',     ["Chrome PDF Viewer"]
    # Disable "Change your password" popup shown after login due to leak detection
    driver_option.add_preference 'profile.password_manager_leak_detection', false
    # Disable password saving prompts
    driver_option.add_preference 'profile.password_manager_enabled', false
    driver_option.add_preference 'credentials_enable_service', false
  end

  setup do
    Capybara.app_host = "http://#{Capybara.server_host}:#{Capybara.server_port}"
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
