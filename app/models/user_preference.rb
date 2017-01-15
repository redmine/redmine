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

class UserPreference < ActiveRecord::Base
  include Redmine::SafeAttributes

  belongs_to :user
  serialize :others

  attr_protected :others, :user_id

  before_save :set_others_hash

  safe_attributes 'hide_mail',
    'time_zone',
    'comments_sorting',
    'warn_on_leaving_unsaved',
    'no_self_notified',
    'textarea_font'

  TEXTAREA_FONT_OPTIONS = ['monospace', 'proportional']

  def initialize(attributes=nil, *args)
    super
    if new_record?
      unless attributes && attributes.key?(:hide_mail)
        self.hide_mail = Setting.default_users_hide_mail?
      end
      unless attributes && attributes.key?(:time_zone)
        self.time_zone = Setting.default_users_time_zone
      end
      unless attributes && attributes.key?(:no_self_notified)
        self.no_self_notified = true
      end
    end
    self.others ||= {}
  end

  def set_others_hash
    self.others ||= {}
  end

  def [](attr_name)
    if has_attribute? attr_name
      super
    else
      others ? others[attr_name] : nil
    end
  end

  def []=(attr_name, value)
    if has_attribute? attr_name
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

  def activity_scope; Array(self[:activity_scope]) ; end
  def activity_scope=(value); self[:activity_scope]=value ; end

  def textarea_font; self[:textarea_font] end
  def textarea_font=(value); self[:textarea_font]=value; end

  def my_page_layout
    self[:my_page_layout] ||= Redmine::MyPage.default_layout.deep_dup
  end

  def my_page_layout=(arg)
    self[:my_page_layout] = arg
  end

  def my_page_settings(block=nil)
    s = self[:my_page_settings] ||= {}
    if block
      s[block] ||= {}
    else
      s
    end
  end

  def my_page_settings=(arg)
    self[:my_page_settings] = arg
  end

  def remove_block(block)
    block = block.to_s.underscore
    %w(top left right).each do |f|
      (my_page_layout[f] ||= []).delete(block)
    end
    my_page_layout
  end

  def add_block(block)
    block = block.to_s.underscore
    return unless Redmine::MyPage.blocks.key?(block)

    remove_block(block)
    # add it on top
    my_page_layout['top'] ||= []
    my_page_layout['top'].unshift(block)
  end

  def update_block_settings(block, settings)
    block_settings = my_page_settings(block).merge(settings.symbolize_keys)
    my_page_settings[block] = block_settings
  end
end
