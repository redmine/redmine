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

require File.expand_path('../../test_helper', __FILE__)

class WikisControllerTest < Redmine::ControllerTest
  fixtures :projects, :users, :roles, :members, :member_roles, :enabled_modules, :wikis

  def setup
    User.current = nil
  end

  def test_get_destroy_should_ask_confirmation
    set_tmp_attachments_directory
    @request.session[:user_id] = 1
    assert_no_difference 'Wiki.count' do
      get :destroy, :params => {:id => 1}
      assert_response :success
    end
  end

  def test_post_destroy_should_delete_wiki
    set_tmp_attachments_directory
    @request.session[:user_id] = 1
    post :destroy, :params => {:id => 1, :confirm => 1}
    assert_redirected_to :controller => 'projects',
                         :action => 'show', :id => 'ecookbook'
    assert_nil Project.find(1).wiki
  end

  def test_not_found
    @request.session[:user_id] = 1
    post :destroy, :params => {:id => 999, :confirm => 1}
    assert_response 404
  end
end
