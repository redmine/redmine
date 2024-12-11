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

require_relative '../../test_helper'

class Redmine::ApiTest::JournalTest < Redmine::ApiTest::Base
  test "PUT /journals/:id.xml with valid parameters should update the journal notes" do
    put(
      '/journals/1.xml',
      params: {
        journal: { notes: 'changed notes' }
      },
      headers: credentials('admin')
    )

    assert_response :no_content
    assert_equal '', @response.body

    journal = Journal.find(1)
    assert_equal 'changed notes', journal.notes
  end

  test "PUT /journals/:id.json with valid parameters should update the journal notes" do
    put(
      '/journals/1.json',
      params: {
        journal: { notes: 'changed notes' }
      },
      headers: credentials('admin')
    )

    assert_response :no_content
    assert_equal '', @response.body

    journal = Journal.find(1)
    assert_equal 'changed notes', journal.notes
  end

  test "PUT /journals/:id.xml without journal details should destroy journal" do
    journal = Journal.find(5)
    assert_equal [], journal.details
    assert_difference('Journal.count', -1) do
      put(
        "/journals/#{journal.id}.xml",
        params: {
          journal: { notes: '' }
        },
        headers: credentials('admin')
      )
    end
    assert_response :no_content
    assert_equal '', @response.body
    assert_nil Journal.find_by(id: 5)
  end

  test "PUT /journals/:id.json without journal details should destroy journal" do
    journal = Journal.find(5)
    assert_equal [], journal.details
    assert_difference('Journal.count', -1) do
      put(
        "/journals/#{journal.id}.json",
        params: {
          journal: { notes: '' }
        },
        headers: credentials('admin')
      )
    end
    assert_response :no_content
    assert_equal '', @response.body
    assert_nil Journal.find_by(id: 5)
  end
end
