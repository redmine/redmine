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

require File.expand_path('../../test_helper', __FILE__)

class CustomValueTest < ActiveSupport::TestCase
  fixtures :custom_fields, :custom_values, :users

  def test_default_value
    field = CustomField.find_by_default_value('Default string')
    assert_not_nil field

    v = CustomValue.new(:custom_field => field)
    assert_equal 'Default string', v.value

    v = CustomValue.new(:custom_field => field, :value => 'Not empty')
    assert_equal 'Not empty', v.value
  end

  def test_sti_polymorphic_association
    # Rails uses top level sti class for polymorphic association. See #3978.
    assert !User.find(4).custom_values.empty?
    assert !CustomValue.find(2).customized.nil?
  end
end
