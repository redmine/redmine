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

class AvatarsHelperTest < Redmine::HelperTest
  include ERB::Util
  include AvatarsHelper

  def setup
    Setting.gravatar_enabled = '1'
  end

  def test_avatar_with_user
    assert_include Digest::SHA256.hexdigest('jsmith@somenet.foo'), avatar(User.find_by_mail('jsmith@somenet.foo'))
  end

  def test_avatar_with_email_string
    assert_include Digest::SHA256.hexdigest('jsmith@somenet.foo'), avatar('jsmith <jsmith@somenet.foo>')
  end

  def test_avatar_with_anonymous_user
    assert_match %r{src="/assets/anonymous(-\w+)?.png"}, avatar(User.anonymous)
  end

  def test_avatar_with_group
    assert_match %r{src="/assets/group(-\w+)?.png"}, avatar(Group.first)
  end

  def test_avatar_with_invalid_arg_should_return_nil
    assert_nil avatar('jsmith')
    assert_nil avatar(nil)
  end

  def test_avatar_default_size_should_be_24
    assert_include 'size=24', avatar('jsmith <jsmith@somenet.foo>')
  end

  def test_avatar_with_size_option
    assert_include 'size=24', avatar('jsmith <jsmith@somenet.foo>', :size => 24)
    assert_include 'width="24" height="24"', avatar(User.anonymous, :size => 24)
  end

  def test_avatar_with_html_option
    # Non-avatar options should be considered html options
    assert_include 'title="John Smith"', avatar('jsmith <jsmith@somenet.foo>', :title => 'John Smith')
  end

  def test_avatar_css_class
    # The default class of the img tag should be gravatar
    assert_include 'class="gravatar"', avatar('jsmith <jsmith@somenet.foo>')
    assert_include 'class="gravatar picture"', avatar('jsmith <jsmith@somenet.foo>', :class => 'picture')
  end

  def test_avatar_disabled
    with_settings :gravatar_enabled => '0' do
      assert_equal '', avatar(User.find_by_mail('jsmith@somenet.foo'))
    end
  end

  def test_avatar_server_url
    to_test = {
      'https://www.gravatar.com' => %r|https://www.gravatar.com/avatar/\h{32}|,
      'https://seccdn.libravatar.org' => %r|https://seccdn.libravatar.org/avatar/\h{32}|,
      'http://localhost:8080' => %r|http://localhost:8080/avatar/\h{32}|,
    }

    to_test.each do |url, expected|
      Redmine::Configuration.with 'avatar_server_url' => url do
        assert_match expected, avatar('<jsmith@somenet.foo>')
      end
    end
  end
end
