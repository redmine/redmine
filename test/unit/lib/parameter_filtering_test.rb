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

class ParameterFilteringTest < ActiveSupport::TestCase
  def filter(params)
    ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(params)
  end

  test "the key parameter should be filtered from logs" do
    filtered = filter('key' => '1234567890abcdef1234567890abcdef12345678')
    assert_equal '[FILTERED]', filtered['key']
  end

  test "passwords should be filtered from logs" do
    assert_equal '[FILTERED]', filter('password' => 'secret')['password']
    assert_equal '[FILTERED]', filter('sudo_password' => 'secret')['sudo_password']
  end

  test "salt should be filtered from logs" do
    assert_equal '[FILTERED]', filter('salt' => 'secret')['salt']
  end

  test "twofa_totp_key should be filtered from logs" do
    assert_equal '[FILTERED]', filter('twofa_totp_key' => 'secret')['twofa_totp_key']
  end

  test "parameters merely containing key should not be over-filtered" do
    assert_equal 'fixes', filter('keywords' => 'fixes')['keywords']
  end
end
