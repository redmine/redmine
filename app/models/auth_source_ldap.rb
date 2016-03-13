# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

require 'net/ldap'
require 'net/ldap/dn'
require 'timeout'

class AuthSourceLdap < AuthSource
  NETWORK_EXCEPTIONS = [
    Net::LDAP::LdapError,
    Errno::ECONNABORTED, Errno::ECONNREFUSED, Errno::ECONNRESET,
    Errno::EHOSTDOWN, Errno::EHOSTUNREACH,
    SocketError
  ]

  validates_presence_of :host, :port, :attr_login
  validates_length_of :name, :host, :maximum => 60, :allow_nil => true
  validates_length_of :account, :account_password, :base_dn, :maximum => 255, :allow_blank => true
  validates_length_of :attr_login, :attr_firstname, :attr_lastname, :attr_mail, :maximum => 30, :allow_nil => true
  validates_numericality_of :port, :only_integer => true
  validates_numericality_of :timeout, :only_integer => true, :allow_blank => true
  validate :validate_filter

  before_validation :strip_ldap_attributes

  def initialize(attributes=nil, *args)
    super
    self.port = 389 if self.port == 0
  end

  def authenticate(login, password)
    return nil if login.blank? || password.blank?

    with_timeout do
      attrs = get_user_dn(login, password)
      if attrs && attrs[:dn] && authenticate_dn(attrs[:dn], password)
        logger.debug "Authentication successful for '#{login}'" if logger && logger.debug?
        return attrs.except(:dn)
      end
    end
  rescue *NETWORK_EXCEPTIONS => e
    raise AuthSourceException.new(e.message)
  end

  # Test the connection to the LDAP
  def test_connection
    with_timeout do
      ldap_con = initialize_ldap_con(self.account, self.account_password)
      ldap_con.open { }

      if self.account.present? && !self.account.include?("$login") && self.account_password.present?
        ldap_auth = authenticate_dn(self.account, self.account_password)
        raise AuthSourceException.new(l(:error_ldap_bind_credentials)) if !ldap_auth
      end
    end
  rescue *NETWORK_EXCEPTIONS => e
    raise AuthSourceException.new(e.message)
  end

  def auth_method_name
    "LDAP"
  end

  # Returns true if this source can be searched for users
  def searchable?
    !account.to_s.include?("$login") && %w(login firstname lastname mail).all? {|a| send("attr_#{a}?")}
  end

  # Searches the source for users and returns an array of results
  def search(q)
    q = q.to_s.strip
    return [] unless searchable? && q.present?

    results = []
    search_filter = base_filter & Net::LDAP::Filter.begins(self.attr_login, q)
    ldap_con = initialize_ldap_con(self.account, self.account_password)
    ldap_con.search(:base => self.base_dn,
                    :filter => search_filter,
                    :attributes => ['dn', self.attr_login, self.attr_firstname, self.attr_lastname, self.attr_mail],
                    :size => 10) do |entry|
      attrs = get_user_attributes_from_ldap_entry(entry)
      attrs[:login] = AuthSourceLdap.get_attr(entry, self.attr_login)
      results << attrs
    end
    results
  rescue *NETWORK_EXCEPTIONS => e
    raise AuthSourceException.new(e.message)
  end

  private

  def with_timeout(&block)
    timeout = self.timeout
    timeout = 20 unless timeout && timeout > 0
    Timeout.timeout(timeout) do
      return yield
    end
  rescue Timeout::Error => e
    raise AuthSourceTimeoutException.new(e.message)
  end

  def ldap_filter
    if filter.present?
      Net::LDAP::Filter.construct(filter)
    end
  rescue Net::LDAP::LdapError, Net::LDAP::FilterSyntaxInvalidError
    nil
  end

  def base_filter
    filter = Net::LDAP::Filter.eq("objectClass", "*")
    if f = ldap_filter
      filter = filter & f
    end
    filter
  end

  def validate_filter
    if filter.present? && ldap_filter.nil?
      errors.add(:filter, :invalid)
    end
  end

  def strip_ldap_attributes
    [:attr_login, :attr_firstname, :attr_lastname, :attr_mail].each do |attr|
      write_attribute(attr, read_attribute(attr).strip) unless read_attribute(attr).nil?
    end
  end

  def initialize_ldap_con(ldap_user, ldap_password)
    options = { :host => self.host,
                :port => self.port,
                :encryption => (self.tls ? :simple_tls : nil)
              }
    options.merge!(:auth => { :method => :simple, :username => ldap_user, :password => ldap_password }) unless ldap_user.blank? && ldap_password.blank?
    Net::LDAP.new options
  end

  def get_user_attributes_from_ldap_entry(entry)
    {
     :dn => entry.dn,
     :firstname => AuthSourceLdap.get_attr(entry, self.attr_firstname),
     :lastname => AuthSourceLdap.get_attr(entry, self.attr_lastname),
     :mail => AuthSourceLdap.get_attr(entry, self.attr_mail),
     :auth_source_id => self.id
    }
  end

  # Return the attributes needed for the LDAP search.  It will only
  # include the user attributes if on-the-fly registration is enabled
  def search_attributes
    if onthefly_register?
      ['dn', self.attr_firstname, self.attr_lastname, self.attr_mail]
    else
      ['dn']
    end
  end

  # Check if a DN (user record) authenticates with the password
  def authenticate_dn(dn, password)
    if dn.present? && password.present?
      initialize_ldap_con(dn, password).bind
    end
  end

  # Get the user's dn and any attributes for them, given their login
  def get_user_dn(login, password)
    ldap_con = nil
    if self.account && self.account.include?("$login")
      ldap_con = initialize_ldap_con(self.account.sub("$login", Net::LDAP::DN.escape(login)), password)
    else
      ldap_con = initialize_ldap_con(self.account, self.account_password)
    end
    attrs = {}
    search_filter = base_filter & Net::LDAP::Filter.eq(self.attr_login, login)
    ldap_con.search( :base => self.base_dn,
                     :filter => search_filter,
                     :attributes=> search_attributes) do |entry|
      if onthefly_register?
        attrs = get_user_attributes_from_ldap_entry(entry)
      else
        attrs = {:dn => entry.dn}
      end
      logger.debug "DN found for #{login}: #{attrs[:dn]}" if logger && logger.debug?
    end
    attrs
  end

  def self.get_attr(entry, attr_name)
    if !attr_name.blank?
      value = entry[attr_name].is_a?(Array) ? entry[attr_name].first : entry[attr_name]
      value.to_s.force_encoding('UTF-8')
    end
  end
end
