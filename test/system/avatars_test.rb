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

require_relative '../application_system_test_case'

class AvatarsTest < ApplicationSystemTestCase
  def test_gravatar_without_default_should_fall_back_to_initials_avatar_if_not_found
    with_settings :gravatar_enabled => '1', :gravatar_default => '' do
      # Requests to /avatar/:hash on Redmine itself respond with 404
      Redmine::Configuration.with 'avatar_server_url' => '' do
        log_user('jsmith', 'jsmith')
        visit '/users/2'

        assert_selector 'h2 span[role="img"].avatar.avatar-color-2.s50.active', :text => 'JS'
        assert_no_selector 'h2 img.gravatar'
      end
    end
  end
end
