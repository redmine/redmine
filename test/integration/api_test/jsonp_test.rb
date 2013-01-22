# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

require File.expand_path('../../../test_helper', __FILE__)

class Redmine::ApiTest::JsonpTest < Redmine::ApiTest::Base
  fixtures :trackers

  def test_jsonp_should_accept_callback_param
    get '/trackers.json?callback=handler'

    assert_response :success
    assert_match %r{^handler\(\{"trackers":.+\}\)$}, response.body
    assert_equal 'application/javascript; charset=utf-8', response.headers['Content-Type']
  end

  def test_jsonp_should_accept_jsonp_param
    get '/trackers.json?jsonp=handler'

    assert_response :success
    assert_match %r{^handler\(\{"trackers":.+\}\)$}, response.body
    assert_equal 'application/javascript; charset=utf-8', response.headers['Content-Type']
  end

  def test_jsonp_should_strip_invalid_characters_from_callback
    get '/trackers.json?callback=+-aA$1_'

    assert_response :success
    assert_match %r{^aA1_\(\{"trackers":.+\}\)$}, response.body
    assert_equal 'application/javascript; charset=utf-8', response.headers['Content-Type']
  end

  def test_jsonp_without_callback_should_return_json
    get '/trackers.json?callback='

    assert_response :success
    assert_match %r{^\{"trackers":.+\}$}, response.body
    assert_equal 'application/json; charset=utf-8', response.headers['Content-Type']
  end
end
