# redMine - project management software
# Copyright (C) 2006-2007  Jean-Philippe Lang
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

class MailingList < ActiveRecord::Base
  belongs_to :project
  belongs_to :admin, :class_name => 'User', :foreign_key => 'admin_id'
  
  validates_presence_of :name, :description
  
  STATUSES = {
	  (STATUS_REQUESTED = 1)     => :mailing_list_status_requested,
      (STATUS_CREATED = 2)       => :mailing_list_status_created,
      (STATUS_TO_BE_DELETED = 3) => :mailing_list_status_to_be_deleted
	}.freeze

  def status_name
    STATUSES[self.status]
  end
  
  # Should be called to create requested lists (from cron, for example)
  # eg: ruby script/runner 'MailingList.create_requested_lists'
  def self.create_requested_lists
    find(:all, :conditions => ["status=?", STATUS_REQUESTED]).each do |list|
      # TO DO: call wrapper to create the list
    end
  end
  
  def self.destroy_unwanted_lists
    find(:all, :conditions => ["status=?", STATUS_TO_BE_DELETED]).each do |list|
      # TO DO: call wrapper to delete the list
    end
  end
end
