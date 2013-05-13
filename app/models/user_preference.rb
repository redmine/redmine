# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

class UserPreference < ActiveRecord::Base
  belongs_to :user
  serialize :others

  attr_protected :others, :user_id

  before_save :set_others_hash

  def initialize(attributes=nil, *args)
    super
    self.others ||= {}
  end

  def set_others_hash
    self.others ||= {}
  end

  def [](attr_name)
    if attribute_present? attr_name
      super
    else
      others ? others[attr_name] : nil
    end
  end

  def []=(attr_name, value)
    if attribute_present? attr_name
      super
    else
      h = (read_attribute(:others) || {}).dup
      h.update(attr_name => value)
      write_attribute(:others, h)
      value
    end
  end

  def comments_sorting; self[:comments_sorting] end
  def comments_sorting=(order); self[:comments_sorting]=order end

  def warn_on_leaving_unsaved; self[:warn_on_leaving_unsaved] || '1'; end
  def warn_on_leaving_unsaved=(value); self[:warn_on_leaving_unsaved]=value; end

  def no_self_notified; (self[:no_self_notified] == true || self[:no_self_notified] == '1'); end
  def no_self_notified=(value); self[:no_self_notified]=value; end
end
