# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

  if ldap_configured?
    test '#authenticate with a valid LDAP user should return the user attributes' do
      auth = AuthSourceLdap.find(1)
      auth.update_attribute :onthefly_register, true

      attributes =  auth.authenticate('example1','123456')
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
      assert_equal nil, auth.authenticate('nouser','123456')
    end

    test '#authenticate without a login should return nil' do
      auth = AuthSourceLdap.find(1)
      assert_equal nil, auth.authenticate('','123456')
    end

    test '#authenticate without a password should return nil' do
      auth = AuthSourceLdap.find(1)
      assert_equal nil, auth.authenticate('edavis','')
    end

    test '#authenticate without filter should return any user' do
      auth = AuthSourceLdap.find(1)
      assert auth.authenticate('example1','123456')
      assert auth.authenticate('edavis', '123456')
    end

    test '#authenticate with filter should return user who matches the filter only' do
      auth = AuthSourceLdap.find(1)
      auth.filter = "(mail=*@redmine.org)"

      assert auth.authenticate('example1','123456')
      assert_nil auth.authenticate('edavis', '123456')
    end

    def test_authenticate_should_timeout
      auth_source = AuthSourceLdap.find(1)
      auth_source.timeout = 1
      def auth_source.initialize_ldap_con(*args); sleep(5); end

      assert_raise AuthSourceTimeoutException do
        auth_source.authenticate 'example1', '123456'
      end
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
      Net::LDAP.stubs(:new).raises(Net::LDAP::LdapError, 'Cannot connect')

      results = AuthSource.search("exa")
      assert_equal [], results
    end
  else
    puts '(Test LDAP server not configured)'
  end
end
