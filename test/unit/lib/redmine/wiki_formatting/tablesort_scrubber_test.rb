# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
# This code is released under the GNU General Public License.

require_relative '../../../../test_helper'

class Redmine::WikiFormatting::TablesortScrubberTest < ActiveSupport::TestCase
  def filter(html)
    fragment = Redmine::WikiFormatting::HtmlParser.parse(html)
    scrubber = Redmine::WikiFormatting::TablesortScrubber.new
    fragment.scrub!(scrubber)
    fragment.to_s
  end

  test 'should not add data-controller attribute by default' do
    table = <<~HTML
      <table>
        <tbody><tr>
          <th>A</th>
          <th>B</th>
        </tr>
        <tr>
          <td></td>
          <td></td>
        </tr>
        <tr>
          <td></td>
          <td></td>
        </tr>
      </tbody></table>
    HTML
    assert_equal table, filter(table)
  end

  test 'should not add data-controller attribute when the table has less than 3 rows' do
    table = <<~HTML
      <table>
        <tbody><tr>
          <th>A</th>
          <th>B</th>
        </tr>
        <tr>
          <td></td>
          <td></td>
        </tr>
      </tbody></table>
    HTML
    with_settings :wiki_tablesort_enabled => 1 do
      assert_equal table, filter(table)
    end
  end

  test 'should add data-controller attribute when the table contains at least 3 rows and enables sorting' do
    input = <<~HTML
      <table>
        <tbody><tr>
          <th>A</th>
          <th>B</th>
        </tr>
        <tr>
          <td></td>
          <td></td>
        </tr>
        <tr>
          <td></td>
          <td></td>
        </tr>
      </tbody></table>
    HTML
    expected = <<~HTML
      <table data-controller="tablesort">
        <tbody><tr data-sort-method="none">
          <th>A</th>
          <th>B</th>
        </tr>
        <tr>
          <td></td>
          <td></td>
        </tr>
        <tr>
          <td></td>
          <td></td>
        </tr>
      </tbody></table>
    HTML
    with_settings :wiki_tablesort_enabled => 1 do
      assert_equal expected, filter(input)
    end
  end
end
