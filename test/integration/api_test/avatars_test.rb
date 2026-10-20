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

require_relative '../../test_helper'

class Redmine::ApiTest::AvatarsTest < Redmine::ApiTest::Base
  def setup
    super
    set_fixtures_attachments_directory
  end

  def teardown
    super
    set_tmp_attachments_directory
  end

  test "GET /users/:user_id/avatar/:avatar_key should accept the API key if login is required" do
    skip unless convert_installed?

    user = User.find(2)
    user.update_column(:avatar_id, 16)
    with_settings :login_required => '1' do
      get "/users/2/avatar/#{user.avatar_key}", :headers => {'X-Redmine-API-Key' => user.api_key}
    end
    assert_response :success
    assert_equal 'image/png', response.media_type
  end
end
