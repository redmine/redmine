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
end
