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

class Redmine::ApiTest::TrackersTest < Redmine::ApiTest::Base
  test "GET /trackers.xml should return trackers" do
    Tracker.find(2).update_attribute :core_fields, %w[assigned_to_id due_date]
    get '/trackers.xml'

    assert_response :success
    assert_equal 'application/xml', @response.media_type

    assert_select 'trackers[type=array] tracker id', :text => '2' do
      assert_select '~ name', :text => 'Feature request'
      assert_select '~ description', :text => 'Description for Feature request tracker'
      assert_select '~ enabled_standard_fields[type=array]' do
        assert_select 'enabled_standard_fields>field', :count => 2
        assert_select 'enabled_standard_fields>field', :text => 'assigned_to_id'
        assert_select 'enabled_standard_fields>field', :text => 'due_date'
      end
    end
  end
end
