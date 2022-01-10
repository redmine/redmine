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

require File.expand_path('../../../../../test_helper', __FILE__)

class URLTest < ActiveSupport::TestCase
  include Redmine::Helpers::URL

  def test_uri_with_safe_scheme
    assert uri_with_safe_scheme?("http://example.com/")
    assert uri_with_safe_scheme?("https://example.com/")
    assert uri_with_safe_scheme?("ftp://example.com/index.html")
    assert uri_with_safe_scheme?("mailto:root@example.com")
  end

  def test_uri_with_safe_scheme_invalid_component
    assert_not uri_with_safe_scheme?("httpx://example.com/")
    assert_not uri_with_safe_scheme?("mailto:root@")
  end

  LINK_SAFE_URIS = [
    "http://example.com/",
    "https://example.com/",
    "ftp://example.com/",
    "foo://example.org",
    "mailto:foo@example.org",
    " http://example.com/",
    "",
    "/javascript:alert(\'filename\')",
  ]

  def test_uri_with_link_safe_scheme_should_recognize_safe_uris
    LINK_SAFE_URIS.each do |uri|
      assert uri_with_link_safe_scheme?(uri), "'#{uri}' should be safe"
    end
  end

  LINK_UNSAFE_URIS = [
    "javascript:alert(\'XSS\');",
    "javascript    :alert(\'XSS\');",
    "javascript:    alert(\'XSS\');",
    "javascript    :   alert(\'XSS\');",
    ":javascript:alert(\'XSS\');",
    "javascript&#58;",
    "javascript&#0058;",
    "javascript&#x3A;",
    "javascript&#x003A;",
    "java\0script:alert(\"XSS\")",
    "java\script:alert(\"XSS\")",
    " \x0e  javascript:alert(\'XSS\');",
    "data:image/png;base64,foobar",
    "vbscript:foobar",
    "data:text/html;base64,foobar",
  ]

  def test_uri_with_link_safe_scheme_should_recognize_unsafe_uris
    LINK_UNSAFE_URIS.each do |uri|
      assert_not uri_with_link_safe_scheme?(uri), "'#{uri}' should not be safe"
    end
  end
end
