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

class AuthSourceLdapTest < ActiveSupport::TestCase
  include Redmine::I18n
  fixtures :auth_sources

  def setup
    User.current = nil
  end

  def test_initialize
    auth_source = AuthSourceLdap.new
    assert_nil auth_source.id
    assert_equal "AuthSourceLdap", auth_source.type
    assert_equal "", auth_source.name
    assert_nil auth_source.host
    assert_nil auth_source.port
    assert_nil auth_source.account
    assert_equal "", auth_source.account_password
    assert_nil auth_source.base_dn
    assert_nil auth_source.attr_login
    assert_nil auth_source.attr_firstname
    assert_nil auth_source.attr_lastname
    assert_nil auth_source.attr_mail
    assert_equal false, auth_source.onthefly_register
    assert_equal false, auth_source.tls
    assert_equal true, auth_source.verify_peer
    assert_equal :ldap, auth_source.ldap_mode
    assert_nil auth_source.filter
    assert_nil auth_source.timeout
  end

  def test_create
    a = AuthSourceLdap.new(:name => 'My LDAP', :host => 'ldap.example.net', :port => 389, :base_dn => 'dc=example,dc=net', :attr_login => 'sAMAccountName')
    assert a.save
  end

  def test_should_strip_ldap_attributes
    a = AuthSourceLdap.new(:name => 'My LDAP', :host => 'ldap.example.net', :port => 389, :base_dn => 'dc=example,dc=net', :attr_login => 'sAMAccountName',
                           :attr_firstname => 'givenName ')
    assert a.save
    assert_equal 'givenName', a.reload.attr_firstname
  end

  def test_replace_port_zero_to_389
    a = AuthSourceLdap.new(
           :name => 'My LDAP', :host => 'ldap.example.net', :port => 0,
           :base_dn => 'dc=example,dc=net', :attr_login => 'sAMAccountName',
           :attr_firstname => 'givenName ')
    assert a.save
    assert_equal 389, a.port
  end

  def test_filter_should_be_validated
    set_language_if_valid 'en'

    a = AuthSourceLdap.new(:name => 'My LDAP', :host => 'ldap.example.net', :port => 389, :attr_login => 'sn')
    a.filter = "(mail=*@redmine.org"
    assert !a.valid?
    assert_include "LDAP filter is invalid", a.errors.full_messages

    a.filter = "(mail=*@redmine.org)"
    assert a.valid?
  end

  test 'ldap_mode setter sets tls and verify_peer' do
    a = AuthSourceLdap.new

    a.ldap_mode = 'ldaps_verify_peer'
    assert a.tls
    assert a.verify_peer

    a.ldap_mode = 'ldaps_verify_none'
    assert a.tls
    assert !a.verify_peer

    a.ldap_mode = 'ldap'
    assert !a.tls
    assert !a.verify_peer
  end

  test 'ldap_mode getter reads from tls and verify_peer' do
    a = AuthSourceLdap.new

    a.tls = true
    a.verify_peer = true
    assert_equal :ldaps_verify_peer, a.ldap_mode

    a.tls = true
    a.verify_peer = false
    assert_equal :ldaps_verify_none, a.ldap_mode

    a.tls = false
    a.verify_peer = false
    assert_equal :ldap, a.ldap_mode

    a.tls = false
    a.verify_peer = true
    assert_equal :ldap, a.ldap_mode
  end

  if ldap_configured?
    test '#authenticate with a valid LDAP user should return the user attributes' do
      auth = AuthSourceLdap.find(1)
      auth.update_attribute :onthefly_register, true

      attributes =  auth.authenticate('example1', '123456')
      assert attributes.is_a?(Hash), "An hash was not returned"
      assert_equal 'Example', attributes[:firstname]
      assert_equal 'One', attributes[:lastname]
      assert_equal 'example1@redmine.org', attributes[:mail]
      assert_equal auth.id, attributes[:auth_source_id]
      attributes.keys.each do |attribute|
        assert User.new.respond_to?("#{attribute}="), "Unexpected :#{attribute} attribute returned"
      end
    end

    test '#authenticate with an invalid LDAP user should return nil' do
      auth = AuthSourceLdap.find(1)
      assert_nil auth.authenticate('nouser', '123456')
    end

    test '#authenticate without a login should return nil' do
      auth = AuthSourceLdap.find(1)
      assert_nil auth.authenticate('', '123456')
    end

    test '#authenticate without a password should return nil' do
      auth = AuthSourceLdap.find(1)
      assert_nil auth.authenticate('edavis', '')
    end

    test '#authenticate without filter should return any user' do
      auth = AuthSourceLdap.find(1)
      assert auth.authenticate('example1', '123456')
      assert auth.authenticate('edavis', '123456')
    end

    test '#authenticate with filter should return user who matches the filter only' do
      auth = AuthSourceLdap.find(1)
      auth.filter = "(mail=*@redmine.org)"

      assert auth.authenticate('example1', '123456')
      assert_nil auth.authenticate('edavis', '123456')
    end

    def test_authenticate_should_timeout
      auth_source = AuthSourceLdap.find(1)
      auth_source.timeout = 1
      def auth_source.initialize_ldap_con(*args); sleep(5); end

      error = assert_raise AuthSourceTimeoutException do
        auth_source.authenticate 'example1', '123456'
      end
      assert_match /\ALDAP: /, error.message
    end

    def test_search_should_return_matching_entries
      results = AuthSource.search("exa")
      assert_equal 1, results.size
      result = results.first
      assert_kind_of Hash, result
      assert_equal "example1", result[:login]
      assert_equal "Example", result[:firstname]
      assert_equal "One", result[:lastname]
      assert_equal "example1@redmine.org", result[:mail]
      assert_equal 1, result[:auth_source_id]
    end

    def test_search_with_no_match_should_return_an_empty_array
      results = AuthSource.search("wro")
      assert_equal [], results
    end

    def test_search_with_exception_should_return_an_empty_array
      Net::LDAP.stubs(:new).raises(Net::LDAP::Error, 'Cannot connect')

      results = AuthSource.search("exa")
      assert_equal [], results
    end

    def test_test_connection_with_correct_host_and_port
      auth_source = AuthSourceLdap.find(1)

      assert_nothing_raised do
        auth_source.test_connection
      end
    end

    def test_test_connection_with_incorrect_host
      auth_source = AuthSourceLdap.find(1)
      auth_source.host = "badhost"
      auth_source.save!

      error = assert_raise AuthSourceException do
        auth_source.test_connection
      end
      assert_match /\ALDAP: /, error.message
    end

    def test_test_connection_with_incorrect_port
      auth_source = AuthSourceLdap.find(1)
      auth_source.port = 1234
      auth_source.save!

      assert_raise AuthSourceException do
        auth_source.test_connection
      end
    end

    def test_test_connection_bind_with_account_and_password
      auth_source = AuthSourceLdap.find(1)
      auth_source.account = "cn=admin,dc=redmine,dc=org"
      auth_source.account_password = "secret"
      auth_source.save!

      assert_equal "cn=admin,dc=redmine,dc=org", auth_source.account
      assert_equal "secret", auth_source.account_password
      assert_nil auth_source.test_connection
    end

    def test_test_connection_bind_without_account_and_password
      auth_source = AuthSourceLdap.find(1)

      assert_nil auth_source.account
      assert_equal "", auth_source.account_password
      assert_nil auth_source.test_connection
    end

    def test_test_connection_bind_with_incorrect_account
      auth_source = AuthSourceLdap.find(1)
      auth_source.account = "cn=baduser,dc=redmine,dc=org"
      auth_source.account_password = "secret"
      auth_source.save!

      assert_equal "cn=baduser,dc=redmine,dc=org", auth_source.account
      assert_equal "secret", auth_source.account_password
      assert_raise AuthSourceException do
        auth_source.test_connection
      end
    end

    def test_test_connection_bind_with_incorrect_password
      auth_source = AuthSourceLdap.find(1)
      auth_source.account = "cn=admin,dc=redmine,dc=org"
      auth_source.account_password = "badpassword"
      auth_source.save!

      assert_equal "cn=admin,dc=redmine,dc=org", auth_source.account
      assert_equal "badpassword", auth_source.account_password
      assert_raise AuthSourceException do
        auth_source.test_connection
      end
    end
  else
    puts '(Test LDAP server not configured)'
  end
end
