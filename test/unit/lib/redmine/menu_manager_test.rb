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

require File.expand_path('../../../../test_helper', __FILE__)

class Redmine::MenuManagerTest < ActiveSupport::TestCase
  def test_map_should_yield_a_mapper
    assert_difference 'Redmine::MenuManager.items(:project_menu).size' do
      Redmine::MenuManager.map :project_menu do |mapper|
        assert_kind_of  Redmine::MenuManager::Mapper, mapper
        mapper.push :new_item, '/'
      end
    end
  end

  def test_items_should_return_menu_items
    items = Redmine::MenuManager.items(:project_menu)
    assert_kind_of Redmine::MenuManager::MenuNode, items.first
  end
end
