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

class EmailAddressTest < ActiveSupport::TestCase
  fixtures :users

  def setup
    User.current = nil
  end

  def test_address_with_punycode_tld_should_be_valid
    email = EmailAddress.new(address: 'jsmith@example.xn--80akhbyknj4f')
    assert email.valid?
  end

  def test_address_should_be_validated_against_denied_domains
    with_settings :email_domains_denied => "black.test\r\nBLACK.EXAMPLE, .subdomain.test" do
      email = EmailAddress.new(address: 'user@black.test')
      assert_not email.valid?
      email = EmailAddress.new(address: 'user@notblack.test')
      assert email.valid?
      email = EmailAddress.new(address: 'user@BLACK.TEST')
      assert_not email.valid?
      email = EmailAddress.new(address: 'user@black.example')
      assert_not email.valid?
      email = EmailAddress.new(address: 'user@subdomain.test')
      assert email.valid?
      email = EmailAddress.new(address: 'user@foo.subdomain.test')
      assert_not email.valid?
    end
  end

  def test_address_should_be_validated_against_allowed_domains
    with_settings :email_domains_allowed => "white.test\r\nWHITE.EXAMPLE, .subdomain.test" do
      email = EmailAddress.new(address: 'user@white.test')
      assert email.valid?
      email = EmailAddress.new(address: 'user@notwhite.test')
      assert_not email.valid?
      email = EmailAddress.new(address: 'user@WHITE.TEST')
      assert email.valid?
      email = EmailAddress.new(address: 'user@white.example')
      assert email.valid?
      email = EmailAddress.new(address: 'user@subdomain.test')
      assert_not email.valid?
      email = EmailAddress.new(address: 'user@foo.subdomain.test')
      assert email.valid?
    end
  end
end
