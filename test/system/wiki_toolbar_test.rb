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

class WikiToolbarTest < ApplicationSystemTestCase
  def test_toolbar_should_be_moved_before_the_textarea
    log_user('jsmith', 'jsmith')
    visit '/projects/ecookbook/issues/new'

    within '#issue_description_and_toolbar' do
      assert_selector 'div.jstBlock div.jstEditor textarea#issue_description'
      assert_selector 'div.jstBlock div.jstTabs + div.jstEditor'
    end
  end

  def test_wrap_selection_using_textile
    with_settings :text_formatting => 'textile' do
      log_user('jsmith', 'jsmith')
      visit '/projects/ecookbook/issues/new'

      fill_in 'Description', :with => 'Some text'
      select_text 'issue_description', 5, 9
      find('button.jstb_strong').click
      assert_equal 'Some *text*', find('#issue_description').value

      fill_in 'Description', :with => 'Some text'
      select_text 'issue_description', 0, 4
      find('button.jstb_link').click
      assert_equal '[[Some]] text', find('#issue_description').value
    end
  end

  def test_wrap_lines_using_common_mark
    with_settings :text_formatting => 'common_mark' do
      log_user('jsmith', 'jsmith')
      visit '/projects/ecookbook/issues/new'

      fill_in 'Description', :with => "## Title"
      find('button.jstb_h1').click
      assert_equal '# Title', find('#issue_description').value

      fill_in 'Description', :with => "first\nsecond"
      select_text 'issue_description', 0, 12
      find('button.jstb_ol').click
      assert_equal "1. first\n1. second", find('#issue_description').value

      select_text 'issue_description', 0, 18
      find('button.jstb_bq').click
      assert_equal "> 1. first\n> 1. second", find('#issue_description').value

      select_text 'issue_description', 0, 22
      find('button.jstb_unbq').click
      assert_equal "1. first\n1. second", find('#issue_description').value

      fill_in 'Description', :with => 'code'
      find('button.jstb_pre').click
      assert_equal "```\ncode\n```", find('#issue_description').value
    end
  end

  def test_insert_table_using_common_mark
    with_settings :text_formatting => 'common_mark' do
      log_user('jsmith', 'jsmith')
      visit '/projects/ecookbook/issues/new'

      find('button.jstb_table').click
      within 'div.jstBlock table.table-generator' do
        find('button[title="2×3"]').hover
        assert_selector 'td.selected-cell', :count => 6
        find('button[title="2×3"]').click
      end
      assert_no_selector 'table.table-generator'
      assert_equal "|A |B |\n|--|--|\n|  |  |\n|  |  |\n|  |  |\n", find('#issue_description').value
    end
  end

  def test_insert_table_using_textile
    with_settings :text_formatting => 'textile' do
      log_user('jsmith', 'jsmith')
      visit '/projects/ecookbook/issues/new'

      find('button.jstb_table').click
      find('table.table-generator button[title="2×1"]').click
      assert_equal "|_.A|_.B|\n|  |  |\n", find('#issue_description').value
    end
  end

  def test_insert_highlighted_code
    with_settings :text_formatting => 'common_mark' do
      log_user('jsmith', 'jsmith')
      visit '/projects/ecookbook/issues/new'

      fill_in 'Description', :with => 'puts 1'
      find('button.jstb_precode').click
      within('ul.jstMenu') {click_button 'ruby'}
      assert_no_selector 'ul.jstMenu'
      assert_equal "``` ruby\nputs 1\n```\n", find('#issue_description').value
    end
  end

  def test_menus_should_close_with_escape_outside_click_or_toggle
    log_user('jsmith', 'jsmith')
    visit '/projects/ecookbook/issues/new'

    find('button.jstb_precode').click
    assert_selector 'ul.jstMenu button:focus'
    find('ul.jstMenu button', match: :first).send_keys(:escape)
    assert_no_selector 'ul.jstMenu'

    find('button.jstb_table').click
    assert_selector 'table.table-generator'
    find('button.jstb_table').click
    assert_no_selector 'table.table-generator'

    find('button.jstb_precode').click
    find('button.jstb_table').click
    assert_no_selector 'ul.jstMenu'
    assert_selector 'table.table-generator'
    find('#issue_subject').click
    assert_no_selector 'table.table-generator'
  end

  def test_full_width_custom_field_should_have_toolbar
    field = IssueCustomField.create!(:name => 'Long text', :field_format => 'text', :full_width_layout => '1',
                                     :text_formatting => 'full', :is_for_all => true, :tracker_ids => [1])
    log_user('jsmith', 'jsmith')
    visit '/projects/ecookbook/issues/new'

    assert_selector "div.jstBlock div.jstEditor textarea#issue_custom_field_values_#{field.id}"
    find("#issue_custom_field_values_#{field.id}").click
    find("div.jstBlock:has(#issue_custom_field_values_#{field.id}) button.jstb_strong").click
    assert_equal '****', find("#issue_custom_field_values_#{field.id}").value
  end

  def test_preview_should_send_attachments_and_toggle_toolbar
    log_user('jsmith', 'jsmith')
    visit '/projects/ecookbook/issues/new'

    fill_in 'Description', :with => 'Preview *me*'
    click_link 'Preview'
    within 'div.jstBlock' do
      assert_selector 'div.wiki-preview', :visible => true, :text => 'Preview me'
      assert_selector 'div.jstElements', :visible => false
      assert_selector 'a.tab-preview.selected[aria-selected=true]'
    end
    click_link 'Edit'
    assert_selector 'div.jstElements', :visible => true
    assert_equal 'issue_description', page.evaluate_script('document.activeElement.id')
  end

  private

  def select_text(id, start, finish)
    page.execute_script("document.getElementById('#{id}').setSelectionRange(#{start}, #{finish})")
  end
end
