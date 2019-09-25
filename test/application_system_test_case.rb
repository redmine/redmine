# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  DOWNLOADS_PATH = File.expand_path(File.join(Rails.root, 'tmp', 'downloads'))

  driven_by :selenium, using: :chrome, screen_size: [1024, 900], options: {
      desired_capabilities: Selenium::WebDriver::Remote::Capabilities.chrome(
        'chromeOptions' => {
          'prefs' => {
            'download.default_directory' => DOWNLOADS_PATH,
            'download.prompt_for_download' => false,
            'plugins.plugins_disabled' => ["Chrome PDF Viewer"]
          }
        }
      )
    }

  setup do
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

  def clear_downloaded_files
    # https://github.com/SeleniumHQ/selenium/issues/5292
    FileUtils.rm downloaded_files if Redmine::Platform.mswin?
  end

  def downloaded_files(filename='*')
    # https://github.com/SeleniumHQ/selenium/issues/5292
    downloaded_path = Redmine::Platform.mswin? ? DOWNLOADS_PATH : "#{ENV['HOME']}/Downloads"
    Dir.glob("#{downloaded_path}/#{filename}").
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
