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

module SettingsHelperPatch
  def self.included(base)
    base.class_eval do
      def setting_time_field(setting, options={})
        setting_label(setting, options).html_safe +
          time_select(
            "settings[#{setting}]",
            setting.to_s,
            { default: { hour: Setting.send(setting).to_time.hour, min: Setting.send(setting).to_time.min } },
            {}
          ).html_safe
      end
    end
  end
end
