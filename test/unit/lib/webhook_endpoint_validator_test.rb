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

class WebhookEndpointValidatorTest < ActiveSupport::TestCase
  class TestModel
    include ActiveModel::Validations
    attr_accessor :url

    def initialize(url)
      self.url = url
    end

    validates :url, webhook_endpoint: true
  end

  setup do
    WebhookEndpointValidator.class_eval do
      @blocked_hosts = nil
    end
  end

  test "should validate url" do
    Redmine::Configuration.with('webhook_blocklist' => ['*.example.org', '10.0.0.0/8', '192.168.0.0/16']) do
      %w[
        mailto:user@example.com
        foobar
        example.com
        file://example.com
        https://x.example.org/
        http://x.example.org/
      ].each do |url|
        assert_not WebhookEndpointValidator.safe_webhook_uri?(url), "#{url} should be invalid"
        record = TestModel.new url
        assert_not record.valid?
        assert record.errors[:url].any?
      end

      assert WebhookEndpointValidator.safe_webhook_uri? 'https://acme.com/some/webhook?foo=bar'
      record = TestModel.new 'https://acme.com/some/webhook?foo=bar'
      assert record.valid?, record.errors.inspect
    end
  end

  test "should validate ports" do
    %w[
      http://example.com:22
      http://example.com:1
    ].each do |url|
      assert_not WebhookEndpointValidator.safe_webhook_uri?(url), "#{url} should be invalid"
    end
    %w[
      http://example.com
      http://example.com:80
      http://example.com:443
      http://example.com:8080
    ].each do |url|
      assert WebhookEndpointValidator.safe_webhook_uri? url
    end
  end

  test "should validate ip addresses" do
    Redmine::Configuration.with('webhook_blocklist' => ['*.example.org', '10.0.0.0/8', '192.168.0.0/16']) do
      %w[
        127.0.0.0
        127.0.0.1
        10.0.0.0
        10.0.1.0
        169.254.1.9
        192.168.2.1
        224.0.0.1
        ::1/128
        fe80::/10
      ].each do |ip|
        assert_not WebhookEndpointValidator.safe_webhook_uri? ip
        h = TestModel.new "http://#{ip}"
        assert_not h.valid?, "IP #{ip} should be invalid"
        assert h.errors[:url].any?
      end
    end
  end
end
