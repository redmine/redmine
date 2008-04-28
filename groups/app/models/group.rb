# redMine - project management software
# Copyright (C) 2008  FreeCode
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

class Group < ActiveRecord::Base
  
  has_many :users, :dependent => :nullify
  has_many :memberships, :class_name => 'Member', :as => :principal, :dependent => :destroy
  has_many :members, :as => :principal,
                     :include => [ :project, :role ],
                     :conditions => "#{Project.table_name}.status=#{Project::STATUS_ACTIVE}",
                     :order => "#{Project.table_name}.name"
  has_many :custom_values, :dependent => :delete_all, :as => :customized
    
  validates_presence_of :name
  validates_uniqueness_of :name
  validates_length_of :name, :maximum => 30
  
  def <=>(group)
    name <=> group.name
  end
  
  def to_s
    name
  end
end
