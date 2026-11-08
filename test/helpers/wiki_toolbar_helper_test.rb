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

class WikiToolbarHelperTest < Redmine::HelperTest
  include ApplicationHelper
  include Redmine::I18n
  helper CustomFieldsHelper, SettingsHelper

  def test_wiki_textarea_tag_should_render_the_textarea_inside_the_toolbar
    with_settings :text_formatting => 'common_mark' do
      html = render_erb("<%= wiki_textarea_tag('content[text]', 'Hello', :rows => 5, :preview_url => '/preview', :data => {:auto_complete => true}) %>")

      assert_select_in html, 'div.jstBlock[data-controller=wiki-toolbar]:not([hidden]):not([data-wiki-toolbar-field-id-value])' do
        assert_select '[data-wiki-toolbar-format-value=common_mark]'
        assert_select '[data-wiki-toolbar-preview-url-value=?]', '/preview'
        assert_select '[data-wiki-toolbar-help-url-value=?]', '/help/wiki_syntax'
        assert_select 'div.jstTabs ul[role=tablist]' do
          assert_select 'a.tab-edit.selected[aria-selected=true]', :text => 'Edit'
          assert_select 'a.tab-preview[aria-selected=false]', :text => 'Preview'
          assert_select 'div.jstElements'
        end
        assert_select 'div.jstEditor' do
          assert_select 'textarea#content_text.wiki-edit[name=?][rows="5"][data-wiki-toolbar-target=field][data-auto-complete=true]',
                        'content[text]', :text => 'Hello'
          assert_select 'textarea[data-controller=?]', 'list-autofill selection-indent table-paste'
          assert_select 'textarea + div.wiki-preview.hidden#preview_content_text[data-wiki-toolbar-target=preview]'
        end
      end
    end
  end

  def test_wiki_textarea_tag_should_render_only_the_textarea_without_text_formatting
    with_settings :text_formatting => '' do
      html = render_erb("<%= wiki_textarea_tag('content[text]', 'Hello') %>")

      assert_select_in html, 'div.jstBlock', 0
      assert_select_in html, 'textarea#content_text.wiki-edit'
    end
  end

  def test_wiki_textarea_tag_should_render_the_editor_of_a_formatter_without_toolbar_buttons
    helper = Module.new do
      def wikitoolbar_for(field_id, preview_url)
        tag.div(:id => "editor-for-#{field_id}")
      end
    end
    Redmine::WikiFormatting.stubs(:helper_for).returns(helper)

    html = render_erb("<%= wiki_textarea_tag('notes') %>")
    assert_select_in html, 'textarea#notes + div#editor-for-notes'
    assert_select_in html, 'div.jstBlock', 0
  end

  def test_wiki_textarea_tag_should_not_duplicate_the_wiki_edit_class
    with_settings :text_formatting => 'textile' do
      html = render_erb("<%= wiki_textarea_tag('notes', '', :class => 'wiki-edit other') %>")
      assert_select_in html, 'textarea[class=?]', 'wiki-edit other'
    end
  end

  def test_common_mark_buttons
    with_settings :text_formatting => 'common_mark' do
      html = render_erb("<%= wiki_textarea_tag('notes') %>")

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
      html = render_erb("<%= wiki_textarea_tag('notes') %>")

      assert_select_in html, 'div.jstBlock[data-wiki-toolbar-format-value=textile]'
      assert_select_in html, 'div.jstElements' do
        assert_select 'button', 18
        assert_select 'button.jstb_tl', 0
      end
    end
  end

  def test_buttons_of_a_helper_including_a_core_helper
    helper = Module.new {include Redmine::WikiFormatting::CommonMark::Helper}
    Redmine::WikiFormatting.stubs(:helper_for).with('foo').returns(helper)

    assert_equal Redmine::WikiFormatting::CommonMark::Helper::WIKI_TOOLBAR_BUTTONS, Redmine::WikiToolbar.buttons('foo')
  end

  def test_buttons_should_be_translated
    with_settings :text_formatting => 'common_mark' do
      set_language_if_valid 'fr'
      html = render_erb("<%= wiki_textarea_tag('notes') %>")

      assert_select_in html, 'a.tab-edit', :text => ::I18n.t(:button_edit, :locale => 'fr')
      assert_select_in html, 'button.jstb_strong[title=?]', ::I18n.t(:label_wiki_toolbar_strong, :locale => 'fr')
    end
  end

  def test_actions
    with_settings :text_formatting => 'common_mark' do
      html = render_erb("<%= wiki_textarea_tag('notes') %>")
      actions = Nokogiri::HTML.fragment(html).at_css('div.jstBlock')['data-action'].split

      assert_equal ['keydown->wiki-toolbar#shortcut',
                    'keydown.ctrl+shift+p@window->wiki-toolbar#togglePreview',
                    'keydown.meta+shift+p@window->wiki-toolbar#togglePreview'], actions
    end
  end

  def test_precode_menu_should_list_the_user_languages
    User.current = User.find(2)
    User.current.pref.update!(:toolbar_language_options => 'ruby,python')

    with_settings :text_formatting => 'textile' do
      html = render_erb("<%= wiki_textarea_tag('notes') %>")

      assert_select_in html, 'template[data-wiki-toolbar-menu=precode] ul.jstMenu[role=menu]' do
        assert_select 'button[role=menuitem]', 2
      end
      assert_select_in html, 'ul.jstMenu button[data-action=?][data-wiki-toolbar-lang-param=ruby]', 'wiki-toolbar#insertPrecode',
                       :text => 'ruby'
    end
  end

  def test_table_menu
    with_settings :text_formatting => 'common_mark' do
      html = render_erb("<%= wiki_textarea_tag('notes') %>")

      assert_select_in html, 'template[data-wiki-toolbar-menu=table] table.table-generator' do
        assert_select 'tr', 5
        assert_select 'td button', 50
        assert_select 'td button[title=?][data-action=?][data-wiki-toolbar-cols-param="3"][data-wiki-toolbar-rows-param="2"]',
                      '3×2', 'wiki-toolbar#insertTable'
      end
    end
  end

  def test_plugin_can_add_custom_button_and_menu
    with_settings :text_formatting => 'common_mark' do
      buttons = Redmine::WikiToolbar.buttons('common_mark') + [%w[custom custom_menu]]
      menus = Redmine::WikiToolbar.menus + %w[custom_menu]

      Redmine::WikiToolbar.stubs(:buttons).returns(buttons)
      Redmine::WikiToolbar.stubs(:menus).returns(menus)

      html = render_erb("<%= wiki_textarea_tag('notes') %>")

      assert_select_in html, 'button.jstb_custom[data-action=?][data-wiki-toolbar-button-param=custom]', 'wiki-toolbar#apply'
      assert_select_in html, 'button.jstb_custom_menu[data-action=?][data-wiki-toolbar-menu-param=custom_menu]', 'wiki-toolbar#toggleMenu'
    end
  end

  def test_wiki_toolbar_should_wrap_the_block
    with_settings :text_formatting => 'common_mark' do
      html = render_erb(<<~ERB)
        <%= wiki_toolbar 'comment_comments', :preview_url => '/preview' do %>
          <%= textarea 'comment', 'comments', wiki_textarea_options(:rows => 3) %>
        <% end %>
      ERB

      assert_select_in html, 'div.jstBlock div.jstEditor textarea#comment_comments[data-wiki-toolbar-target=field]'
      assert_select_in html, 'div.wiki-preview#preview_comment_comments'
    end
  end

  def test_custom_field_tag_with_wiki_toolbar
    field = IssueCustomField.create!(:name => 'Long text', :field_format => 'text', :text_formatting => 'full')
    value = CustomFieldValue.new(:custom_field => field, :customized => Issue.new)

    with_settings :text_formatting => 'common_mark' do
      html = render_erb("<%= custom_field_tag_with_label(:issue, value, :wiki_toolbar => true, :preview_url => '/preview') %>", :value => value)
      assert_select_in html, "label[for=issue_custom_field_values_#{field.id}]"
      assert_select_in html, "div.jstBlock[data-wiki-toolbar-preview-url-value='/preview'] textarea#issue_custom_field_values_#{field.id}.wiki-edit"

      html = render_erb("<%= custom_field_tag_with_label(:issue, value) %>", :value => value)
      assert_select_in html, 'div.jstBlock', 0
      assert_select_in html, "textarea#issue_custom_field_values_#{field.id}.wiki-edit[data-auto-complete=true]"
    end
  end

  def test_setting_textarea_with_wiki_toolbar
    with_settings :text_formatting => 'common_mark' do
      html = render_erb("<%= setting_textarea(:welcome_text, :rows => 5, :wiki_toolbar => true) %>")
      assert_select_in html, 'label[for=settings_welcome_text]'
      assert_select_in html, 'div.jstBlock textarea#settings_welcome_text.wiki-edit[rows="5"]'
    end
  end

  def test_wikitoolbar_for_should_render_toolbar_adopting_the_field
    with_settings :text_formatting => 'common_mark' do
      html = nil
      assert_deprecated(/wikitoolbar_for is deprecated/, Rails.application.deprecators[:redmine]) do
        html = render_erb("<%= wikitoolbar_for('issue_description', '/issues/preview') %>")
      end

      assert_select_in html, 'div.jstBlock[hidden][data-wiki-toolbar-field-id-value=issue_description]' do
        assert_select 'div.jstEditor textarea', 0
        assert_select 'div.wiki-preview#preview_issue_description'
      end
    end
  end

  def test_wikitoolbar_for_should_render_nothing_without_text_formatting
    with_settings :text_formatting => '' do
      assert_nil wikitoolbar_for('issue_description')
    end
  end

  def test_wikitoolbar_for_should_render_nothing_without_buttons
    helper = Module.new {include Redmine::WikiToolbar::Helper}
    Redmine::WikiFormatting.stubs(:helper_for).returns(helper)

    assert_deprecated(/wikitoolbar_for is deprecated/, Rails.application.deprecators[:redmine]) do
      assert_nil wikitoolbar_for('issue_description')
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

  private

  # Renders the helpers from a template, as in the views
  def render_erb(template, locals = {})
    render(:inline => template, :locals => locals) # rubocop:disable Rails/RenderInline
  end
end
