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

class AvatarsControllerTest < Redmine::ControllerTest
  def setup
    User.current = nil
    set_fixtures_attachments_directory
    User.find(2).update_column(:avatar_id, 16)
  end

  def teardown
    set_tmp_attachments_directory
  end

  def test_show
    skip unless convert_installed?

    get :show, :params => {:user_id => 2, :avatar_key => User.find(2).avatar_key, :size => 48}
    assert_response :success
    assert_equal 'image/png', response.media_type
    assert_match /\Ainline/, response.headers['Content-Disposition']
    assert_equal "max-age=#{1.day.to_i}, public", response.headers['Cache-Control']
  end

  def test_show_should_not_serve_original_image_if_thumbnail_cannot_be_generated
    Attachment.any_instance.stubs(:thumbnail).returns(nil)
    get :show, :params => {:user_id => 2, :avatar_key => User.find(2).avatar_key}
    assert_response :not_found
  end

  def test_show_should_return_404_with_avatars_disabled
    Redmine::Thumbnail.stubs(:convert_available?).returns(true)
    with_settings :avatar_enabled => '0' do
      get :show, :params => {:user_id => 2, :avatar_key => User.find(2).avatar_key}
    end
    assert_response :not_found
  end

  def test_show_should_return_404_for_replaced_avatar
    key = User.find(2).avatar_key
    User.find(2).update_column(:avatar_id, 15)
    get :show, :params => {:user_id => 2, :avatar_key => key}
    assert_response :not_found
  end

  def test_show_should_require_login_if_login_is_required
    with_settings :login_required => '1' do
      get :show, :params => {:user_id => 2, :avatar_key => User.find(2).avatar_key}
      assert_response :redirect
    end
  end
end
