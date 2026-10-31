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

require_relative '../../../test_helper'

class Redmine::WikiToolbarTest < Redmine::HelperTest
  include ApplicationHelper

  def test_wikitoolbar_for_should_render_toolbar_for_the_field
    with_settings :text_formatting => 'common_mark' do
      html = wikitoolbar_for('issue_description', '/issues/preview')

      assert_select_in html, 'div.jstBlock[hidden][data-controller=?]', 'wiki-toolbar' do
        assert_select '[data-wiki-toolbar-field-id-value=?]', 'issue_description'
        assert_select '[data-wiki-toolbar-preview-url-value=?]', '/issues/preview'
        assert_select '[data-wiki-toolbar-help-url-value=?]', '/help/wiki_syntax'
        assert_select 'div.jstTabs ul[role=tablist]' do
          assert_select 'a.tab-edit.selected[aria-selected=true]', :text => 'Edit'
          assert_select 'a.tab-preview[aria-selected=false]', :text => 'Preview'
          assert_select 'div.jstElements'
        end
        assert_select 'div.jstEditor div.wiki-preview.hidden#preview_issue_description'
      end
    end
  end

  def test_wikitoolbar_for_should_render_nothing_without_text_formatting
    with_settings :text_formatting => '' do
      assert_nil wikitoolbar_for('issue_description')
    end
  end

  def test_common_mark_buttons
    with_settings :text_formatting => 'common_mark' do
      html = wikitoolbar_for('issue_description')

      assert_select_in html, 'div.jstBlock[data-wiki-toolbar-format-value=common_mark]'
      assert_select_in html, 'div.jstElements' do
        assert_select 'button', 19
        assert_select 'span.jstSpacer', 5
        assert_select 'button.jstb_strong[title=?][data-action=?][data-wiki-toolbar-button-param=strong][data-wiki-toolbar-shortcut=b]',
                      'Strong', 'wiki-toolbar#apply'
        assert_select 'button.jstb_tl[data-wiki-toolbar-button-param=tl]'
        assert_select 'button.jstb_table[data-action=?][data-wiki-toolbar-menu-param=table]', 'wiki-toolbar#toggleMenu'
        assert_select 'button.jstb_precode[data-action=?][data-wiki-toolbar-menu-param=precode]', 'wiki-toolbar#toggleMenu'
        assert_select 'button.jstb_help[data-action=?]', 'wiki-toolbar#help'
      end
    end
  end

  def test_textile_buttons
    with_settings :text_formatting => 'textile' do
      html = wikitoolbar_for('issue_description')

      assert_select_in html, 'div.jstBlock[data-wiki-toolbar-format-value=textile]'
      assert_select_in html, 'div.jstElements' do
        assert_select 'button', 18
        assert_select 'button.jstb_tl', 0
      end
    end
  end

  def test_buttons_should_be_translated
    with_settings :text_formatting => 'common_mark' do
      set_language_if_valid 'fr'
      html = wikitoolbar_for('issue_description')

      assert_select_in html, 'a.tab-edit', :text => ::I18n.t(:button_edit, :locale => 'fr')
      assert_select_in html, 'button.jstb_strong[title=?]', ::I18n.t(:label_wiki_toolbar_strong, :locale => 'fr')
    end
  end

  def test_keyboard_shortcuts
    with_settings :text_formatting => 'common_mark' do
      html = wikitoolbar_for('issue_description')
      actions = Nokogiri::HTML.fragment(html).at_css('div.jstBlock')['data-action'].split

      assert_equal ['keydown->wiki-toolbar#shortcut',
                    'keydown.ctrl+shift+p@window->wiki-toolbar#togglePreview',
                    'keydown.meta+shift+p@window->wiki-toolbar#togglePreview'], actions
      assert_select_in html, 'button[data-wiki-toolbar-shortcut]', 3
    end
  end

  def test_precode_menu_should_list_the_user_languages
    User.current = User.find(2)
    User.current.pref.update!(:toolbar_language_options => 'ruby,python')

    with_settings :text_formatting => 'textile' do
      html = wikitoolbar_for('issue_description')

      assert_select_in html, 'template[data-wiki-toolbar-target=precodeMenu] ul.jstMenu[role=menu]' do
        assert_select 'button[role=menuitem]', 2
      end
      assert_select_in html, 'ul.jstMenu button[data-action=?][data-wiki-toolbar-lang-param=ruby]', 'wiki-toolbar#insertPrecode', :text => 'ruby'
    end
  end

  def test_table_menu
    with_settings :text_formatting => 'common_mark' do
      html = wikitoolbar_for('issue_description')

      assert_select_in html, 'template[data-wiki-toolbar-target=tableMenu] table.table-generator' do
        assert_select 'tr', 5
        assert_select 'td button', 50
        assert_select 'td button[title=?][data-action=?][data-wiki-toolbar-cols-param="3"][data-wiki-toolbar-rows-param="2"]',
                      '3×2', 'wiki-toolbar#insertTable'
      end
    end
  end

  def test_heads_for_wiki_formatter_should_only_define_image_mime_types
    with_settings :text_formatting => 'common_mark' do
      heads_for_wiki_formatter
      heads_for_wiki_formatter
      header_tags = content_for(:header_tags)

      assert_include 'var wikiImageMimeTypes = ', header_tags
      assert_equal 1, header_tags.scan('wikiImageMimeTypes').size
      assert_not_include 'jstoolbar', header_tags
    end
  end
end
