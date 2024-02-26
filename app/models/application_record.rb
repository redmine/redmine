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
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # Translate attribute names for validation errors display
  def self.human_attribute_name(attr, options = {})
    prepared_attr = attr.to_s.sub(/_id$/, '').sub(/^.+\./, '')
    class_prefix = name.underscore.tr('/', '_')
    redmine_default = [
      :"field_#{class_prefix}_#{prepared_attr}",
      :"field_#{prepared_attr}"
    ]
    options[:default] = redmine_default + Array(options[:default])
    super
  end
end
