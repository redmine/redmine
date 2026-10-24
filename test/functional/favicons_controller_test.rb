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

class FaviconsControllerTest < Redmine::ControllerTest
  def test_show_should_be_cached_and_available_without_login
    data = File.binread(file_fixture('2010/11/101123161450_testfile_1.png'))
    digest = Digest::SHA256.hexdigest(data)[0, 8]
    favicon = {'content_type' => 'image/png', 'data' => Base64.strict_encode64(data), 'digest' => digest}
    with_settings :favicon => favicon, :login_required => '1' do
      get :show, :params => {:digest => digest}
      assert_response :success

      assert_equal 'image/png', response.media_type
      assert_equal data, response.body
      assert_equal "max-age=#{1.year.to_i}, public, immutable", response.headers['Cache-Control']
    end
  end
end
