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

require_relative '../application_system_test_case'

class QuerySystemTest < ApplicationSystemTestCase
  def test_query_filter_row_should_escape_html_elements
    cf = IssueCustomField.create!(name: 'My <select>', field_format: 'string', is_filter: true)

    log_user('jsmith', 'jsmith')
    visit '/issues'
    # click_on 'Add filter'
    select 'My <select>', from: 'Add filter'

    assert_selector "div#tr_cf_#{cf.id} label", text: 'My <select>'
  end
end
