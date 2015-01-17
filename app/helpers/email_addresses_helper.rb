# encoding: utf-8
#
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

module EmailAddressesHelper

  # Returns a link to enable or disable notifications for the address
  def toggle_email_address_notify_link(address)
    if address.notify?
      link_to image_tag('email.png'),
        user_email_address_path(address.user, address, :notify => '0'),
        :method => :put,
        :title => l(:label_disable_notifications),
        :remote => true
    else
      link_to image_tag('email_disabled.png'),
        user_email_address_path(address.user, address, :notify => '1'),
        :method => :put,
        :title => l(:label_enable_notifications),
        :remote => true
    end
  end
end
