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

module ContextMenus
  class NonWorkingDatesControllerTest < Redmine::ControllerTest
    def setup
      User.current = nil
      @request.session[:user_id] = 1 # admin
    end

    def test_context_menu_with_one_non_working_date
      non_working_date = NonWorkingDate.create!(:date => '2026-06-25')

      get :index, :params => {:ids => [non_working_date.id]}
      assert_response :success
      assert_select 'a.icon-edit[href=?]', "/non_working_dates/#{non_working_date.id}/edit"
      assert_select 'a.icon-del[href$=?]', "/non_working_dates/bulk_destroy?ids%5B%5D=#{non_working_date.id}"
    end

    def test_context_menu_with_multiple_non_working_dates
      ids = %w(2026-08-13 2026-08-14).map {|date| NonWorkingDate.create!(:date => date).id}

      get :index, :params => {:ids => ids}
      assert_response :success
      assert_select 'a.icon-edit', 0
      assert_select 'a.icon-del[href$=?]', "/non_working_dates/bulk_destroy?ids%5B%5D=#{ids[0]}&ids%5B%5D=#{ids[1]}"
    end
  end
end
