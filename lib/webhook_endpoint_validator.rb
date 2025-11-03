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

require 'uri'

class WebhookEndpointValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    unless self.class.safe_webhook_uri?(value)
      record.errors.add attribute, :invalid
    end
  end

  def self.safe_webhook_uri?(value)
    uri = value.is_a?(URI) ? value : URI.parse(value)
    return false if uri.nil?

    return false unless valid_scheme?(uri.scheme)
    return false unless valid_host?(uri.host)
    return false unless valid_port?(uri.port)

    true
  rescue
    Rails.logger.warn { "URI failed webhook safety checks: #{uri}" }
    false
  end

  def self.valid_port?(port)
    !BAD_PORTS.include?(port)
  end

  def self.valid_scheme?(scheme)
    %w[http https].include?(scheme)
  end

  def self.blocked_hosts
    @blocked_hosts ||= begin
      ips = []
      wildcards = []
      hosts = []

      Array(Redmine::Configuration['webhook_blocklist']).map(&:to_s).each do |block|
        # We try to parse the block as an IP address first...
        ips << IPAddr.new(block)
      rescue IPAddr::Error
        # If that failed, we assume it is a (wildcard) hostname
        if block.start_with?('*.')
          wildcards << Regexp.escape(block[2..])
        else
          hosts << Regexp.escape(block)
        end
      end

      regex_parts = []
      regex_parts << "(?:#{hosts.join('|')})" if hosts.any?
      regex_parts << "(?:.*\\.)?(?:#{wildcards.join('|')})" if wildcards.any?

      {
        ips: ips.freeze,
        host: regex_parts.any? ? /\A(?:#{regex_parts.join('|')})\z/i : nil
      }.freeze
    end
  end

  def self.valid_host?(host)
    return false if host.blank?

    return false if blocked_hosts[:host]&.match?(host)

    Resolv.each_address(host) do |ip|
      ipaddr = IPAddr.new(ip)
      return false if ipaddr.link_local? || ipaddr.loopback?
      return false if IPAddr.new('224.0.0.0/24').include?(ipaddr) # multicast
      return false if blocked_hosts[:ips].any? { |net| net.include?(ipaddr) }
    end

    true
  end

  # A general port blacklist.  Connections to these ports will not be allowed
  # unless the protocol overrides.
  #
  # This list is to be kept in sync with "bad ports" as defined in the
  # WHATWG Fetch standard at https://fetch.spec.whatwg.org/#port-blocking
  #
  # see also: https://github.com/mozilla/gecko-dev/blob/d55e89d48a8053ce45a74b0ec92c0ff6a9dcc43d/netwerk/base/nsIOService.cpp#L109-L199
  #
  BAD_PORTS = Set[
    1,      # tcpmux
    7,      # echo
    9,      # discard
    11,     # systat
    13,     # daytime
    15,     # netstat
    17,     # qotd
    19,     # chargen
    20,     # ftp-data
    21,     # ftp
    22,     # ssh
    23,     # telnet
    25,     # smtp
    37,     # time
    42,     # name
    43,     # nicname
    53,     # domain
    69,     # tftp
    77,     # priv-rjs
    79,     # finger
    87,     # ttylink
    95,     # supdup
    101,    # hostriame
    102,    # iso-tsap
    103,    # gppitnp
    104,    # acr-nema
    109,    # pop2
    110,    # pop3
    111,    # sunrpc
    113,    # auth
    115,    # sftp
    117,    # uucp-path
    119,    # nntp
    123,    # ntp
    135,    # loc-srv / epmap
    137,    # netbios
    139,    # netbios
    143,    # imap2
    161,    # snmp
    179,    # bgp
    389,    # ldap
    427,    # afp (alternate)
    465,    # smtp (alternate)
    512,    # print / exec
    513,    # login
    514,    # shell
    515,    # printer
    526,    # tempo
    530,    # courier
    531,    # chat
    532,    # netnews
    540,    # uucp
    548,    # afp
    554,    # rtsp
    556,    # remotefs
    563,    # nntp+ssl
    587,    # smtp (outgoing)
    601,    # syslog-conn
    636,    # ldap+ssl
    989,    # ftps-data
    990,    # ftps
    993,    # imap+ssl
    995,    # pop3+ssl
    1719,   # h323gatestat
    1720,   # h323hostcall
    1723,   # pptp
    2049,   # nfs
    3659,   # apple-sasl
    4045,   # lockd
    4190,   # sieve
    5060,   # sip
    5061,   # sips
    6000,   # x11
    6566,   # sane-port
    6665,   # irc (alternate)
    6666,   # irc (alternate)
    6667,   # irc (default)
    6668,   # irc (alternate)
    6669,   # irc (alternate)
    6679,   # osaut
    6697,   # irc+tls
    10080  # amanda
  ].freeze
end
