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

require_relative '../test_helper'

class NonWorkingDateImportTest < ActiveSupport::TestCase
  include Redmine::I18n

  def setup
    set_language_if_valid 'en'
    User.current = nil
  end

  def test_run_should_import_dates_and_names
    import = generate_import_with_mapping
    first, second, third = new_records(NonWorkingDate, 3) {import.run}

    assert_equal Date.new(2026, 6, 25), first.date
    assert_equal 'Company Foundation Day', first.name
    assert_equal Date.new(2026, 8, 13), second.date
    assert_equal 'Summer Shutdown', second.name
    assert_equal Date.new(2026, 12, 30), third.date
    assert_equal 'Year-end Shutdown', third.name
  end

  def test_run_should_not_import_already_registered_dates
    NonWorkingDate.create!(:date => '2026-08-13', :name => 'Existing')
    import = generate_import_with_mapping

    assert_difference 'NonWorkingDate.count', 2 do
      import.run
    end
    assert_equal 'Existing', NonWorkingDate.find_by(:date => '2026-08-13').name
    item = import.unsaved_items.first
    assert_equal 2, item.position
    assert_include 'Date has already been taken', item.message
  end

  protected

  def generate_import_with_mapping
    import = NonWorkingDateImport.new
    import.user_id = 1
    import.file = uploaded_test_file('import_non_working_dates.csv', 'text/csv')
    import.settings = {
      'separator' => ',', 'wrapper' => '"', 'encoding' => 'UTF-8', 'date_format' => '%Y-%m-%d',
      'mapping' => {'date' => '0', 'name' => '1'}
    }
    import.save!
    import
  end
end
