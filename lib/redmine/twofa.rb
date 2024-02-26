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

module Redmine
  module Twofa
    def self.register_scheme(name, klass)
      initialize_schemes
      @@schemes[name] = klass
    end

    def self.available_schemes
      schemes.keys
    end

    def self.for_twofa_scheme(name)
      schemes[name]
    end

    def self.for_user(user)
      for_twofa_scheme(user.twofa_scheme).try(:new, user)
    end

    def self.unpair_all!
      users = User.where.not(twofa_scheme: nil)
      users.each {|u| self.for_user(u).destroy_pairing_without_verify!}
    end

    def self.schemes
      initialize_schemes
      @@schemes
    end
    private_class_method :schemes

    def self.initialize_schemes
      @@schemes ||= {}
      scan_builtin_schemes if @@schemes.blank?
    end
    private_class_method :initialize_schemes

    def self.scan_builtin_schemes
      Dir[Rails.root.join('lib', 'redmine', 'twofa', '*.rb')].each do |file|
        require file
      end
    end
    private_class_method :scan_builtin_schemes
  end
end
