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

  def test_edit
    Redmine::Thumbnail.stubs(:convert_available?).returns(true)
    @request.session[:user_id] = 2
    get :edit
    assert_response :success
    assert_select 'img.avatar[src=?]', "/users/2/avatar/#{User.find(2).avatar_key}/100"
    assert_select 'a.icon-download[href=?]', '/attachments/download/16/testfile.png'
    assert_select 'a.icon-del[href="/my/avatar"][data-method="delete"]'
    assert_select 'form[action="/my/avatar"][enctype="multipart/form-data"] p' do
      assert_select 'input[type=file][name=avatar] + input[type=submit][value=Update]'
    end
  end

  def test_edit_with_avatars_disabled
    @request.session[:user_id] = 2
    with_settings :avatar_enabled => '0' do
      get :edit
    end
    assert_response :success
    assert_select 'p', :text => /disabled by the administrator/
    assert_select 'a.icon-del[href="/my/avatar"]', 0
    assert_select 'input[type=file]', 0
  end

  def test_edit_with_user_id
    Redmine::Thumbnail.stubs(:convert_available?).returns(true)
    @request.session[:user_id] = 1
    get :edit, :params => {:user_id => 2}
    assert_response :success
    assert_select 'h2 a[href="/users/2/edit"]'
    assert_select 'form[action="/users/2/avatar"]'
  end

  def test_edit_with_user_id_should_require_admin
    @request.session[:user_id] = 2
    get :edit, :params => {:user_id => 2}
    assert_response :forbidden
  end

  def test_update
    skip unless convert_installed?

    set_tmp_attachments_directory
    @request.session[:user_id] = 2
    put :update, :params => {:avatar => fixture_file_upload('2010/11/101123161450_testfile_1.png', 'image/png')}
    assert_redirected_to '/my/avatar'
    assert_equal 'Successful update.', flash[:notice]

    avatar = User.find(2).avatar
    assert_equal '101123161450_testfile_1.png', avatar.filename
    assert_equal User.find(2), avatar.author
  end

  def test_destroy
    Redmine::Thumbnail.stubs(:convert_available?).returns(true)
    set_tmp_attachments_directory
    @request.session[:user_id] = 1
    delete :destroy, :params => {:user_id => 2}
    assert_redirected_to '/users/2/avatar'
    assert_equal 'Successful deletion.', flash[:notice]
    assert_nil User.find(2).avatar_id
  end
end
