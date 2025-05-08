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

class WelcomeTest < Redmine::IntegrationTest
  def test_robots
    Project.find(3).update_attribute :status, Project::STATUS_CLOSED

    get '/robots.txt'
    assert_response :success
    assert_equal 'text/plain', @response.media_type
    # Redmine::Utils.relative_url_root does not effect on Rails 5.1.4.
    assert @response.body.match(%r{^Disallow: /projects/ecookbook/issues\r?$})
    assert @response.body.match(%r{^Disallow: /issues\?\*sort=\r?$})
    assert @response.body.match(%r{^Disallow: /issues\?\*set_filter=\r?$})
    assert @response.body.match(%r{^Disallow: /issues/\*\.pdf\$\r?$})
    assert @response.body.match(%r{^Disallow: /projects/\*\.pdf\$\r?$})
    assert @response.body.match(%r{^Disallow: /login\r?$})
    assert @response.body.match(%r{^Disallow: /account/register\r?$})
    assert @response.body.match(%r{^Disallow: /account/lost_password\r?$})

    # closed projects are included in the list
    assert @response.body.match(%r{^Disallow: /projects/subproject1/issues\r?$})
  end

  def test_robots_when_login_is_required
    with_settings :login_required => '1' do
      get '/robots.txt'
      assert_response :success
      assert_equal 'text/plain', @response.media_type

      # Disallow everything if logins are required
      assert_not @response.body.match(%r{^Disallow: /projects/ecookbook/issues\r?$})
      assert @response.body.match(%r{^Disallow: /\r?$})
    end
  end

  def test_robots_should_not_respond_to_formats_other_than_txt
    %w(robots.json robots).each do |file|
      get "/#{file}"
      assert_response :not_found
    end
  end
end
