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

module Redmine
  # Renders the wiki toolbar handled by the wiki-toolbar Stimulus controller.
  #
  # Text formatters subclass it and describe their buttons in #buttons. Each
  # button is a Hash with:
  # * :name - the button name, used for the "jstb_<name>" CSS class
  # * :action - the controller action: wrap, wrapLines or help
  # * :menu - :precode or :table, opens a menu instead of running an action
  # * :shortcut - optional key used with Ctrl (Cmd on macOS)
  # * any other key is passed to the action as a Stimulus action parameter
  #
  # Use SPACER to separate groups of buttons.
  class WikiToolbar
    SPACER = :spacer

    LABELS = {
      'strong' => :label_wiki_toolbar_strong,
      'em' => :label_wiki_toolbar_italic,
      'ins' => :label_wiki_toolbar_underline,
      'del' => :label_wiki_toolbar_deleted,
      'code' => :label_wiki_toolbar_code,
      'h1' => :label_wiki_toolbar_heading_1,
      'h2' => :label_wiki_toolbar_heading_2,
      'h3' => :label_wiki_toolbar_heading_3,
      'ul' => :label_wiki_toolbar_unordered_list,
      'ol' => :label_wiki_toolbar_ordered_list,
      'tl' => :label_wiki_toolbar_task_list,
      'bq' => :label_wiki_toolbar_quote,
      'unbq' => :label_wiki_toolbar_unquote,
      'table' => :label_wiki_toolbar_table,
      'pre' => :label_wiki_toolbar_preformatted_text,
      'precode' => :label_wiki_toolbar_preformatted_code,
      'link' => :label_wiki_toolbar_wiki_link,
      'img' => :label_wiki_toolbar_image,
      'help' => :label_wiki_toolbar_help
    }.freeze

    BUTTON_KEYS = [:name, :action, :menu, :shortcut, :label].freeze
    # Button options used to render the menu instead of being action parameters
    MENU_KEYS = {precode: [:prefix, :suffix]}.freeze
    TABLE_MENU_ROWS = 5
    TABLE_MENU_COLS = 10

    # Helper methods shared by the text formatters that use the toolbar
    module Helper
      def wikitoolbar_for(field_id, preview_url = preview_text_path)
        heads_for_wiki_formatter
        wiki_toolbar.render(field_id, preview_url)
      end

      def heads_for_wiki_formatter
        return if @heads_for_wiki_formatter_included

        content_for :header_tags do
          javascript_tag("var wikiImageMimeTypes = #{Redmine::MimeType.by_type('image').to_json};")
        end
        @heads_for_wiki_formatter_included = true
      end
    end

    def initialize(view)
      @view = view
    end

    def buttons
      []
    end

    def render(field_id, preview_url)
      tag.div(class: 'jstBlock', hidden: true,
              data: {
                controller: 'wiki-toolbar',
                action: keyboard_actions,
                wiki_toolbar_field_id_value: field_id,
                wiki_toolbar_preview_url_value: preview_url,
                wiki_toolbar_help_url_value: @view.help_wiki_syntax_path
              }) do
        tabs +
          tag.div(class: 'jstEditor', data: {wiki_toolbar_target: 'editor'}) do
            tag.div('', class: 'wiki wiki-preview hidden', id: "preview_#{field_id}",
                    data: {wiki_toolbar_target: 'preview'})
          end +
          menus
      end
    end

    private

    def tag
      @view.tag
    end

    def l(...)
      @view.l(...)
    end

    def tabs
      tag.div(class: 'jstTabs tabs') do
        tag.ul(role: 'tablist') do
          tag.li {tab(l(:button_edit), 'edit', true)} +
            tag.li {tab(l(:label_preview), 'preview', false)} +
            tag.li(class: 'tab-elements') do
              tag.div(rendered_buttons, class: 'jstElements', data: {wiki_toolbar_target: 'toolbar'})
            end
        end
      end
    end

    def tab(text, name, selected)
      tag.a(text, href: '#', class: ['tab-' + name, {selected: selected}], role: 'tab',
            aria: {selected: selected},
            data: {wiki_toolbar_target: "#{name}Tab", action: "wiki-toolbar##{name}:prevent"})
    end

    def rendered_buttons
      @rendered_buttons ||= @view.safe_join(buttons.map {|button| render_button(button)})
    end

    def render_button(button)
      return tag.span(" ", class: 'jstSpacer') if button == SPACER

      name = button[:name]
      title = l(button[:label] || LABELS.fetch(name))
      data = button_params(button)
      if button[:menu]
        data[:action] = 'wiki-toolbar#toggleMenu'
        data[:wiki_toolbar_menu_param] = button[:menu]
      else
        data[:action] = "wiki-toolbar##{button[:action]}"
      end
      data[:wiki_toolbar_shortcut] = button[:shortcut] if button[:shortcut]

      tag.button(tag.span(title), type: 'button', class: "jstb_#{name}", title: title, tabindex: 200, data: data)
    end

    # Converts the button options to Stimulus action parameters
    def button_params(button)
      button.except(*BUTTON_KEYS, *MENU_KEYS[button[:menu]]).transform_keys {|key| :"wiki_toolbar_#{key}_param"}
    end

    def menus
      @menus ||= begin
        templates = buttons.filter_map do |button|
          next unless button.is_a?(Hash) && button[:menu]

          tag.template(data: {wiki_toolbar_target: "#{button[:menu]}Menu"}) do
            send(:"#{button[:menu]}_menu", button)
          end
        end
        @view.safe_join(templates)
      end
    end

    # Lists the languages for code highlighting. Each item wraps the selected
    # lines using the :prefix and :suffix of the button, where %{lang} is
    # replaced by the language.
    def precode_menu(button)
      tag.ul(class: 'jstMenu', role: 'menu',
             data: {action: 'click->wiki-toolbar#closeMenu keydown.esc->wiki-toolbar#closeMenu'}) do
        @view.safe_join(
          code_languages.map do |lang|
            tag.li(role: 'none') do
              tag.button(lang, type: 'button', role: 'menuitem',
                         data: {
                           action: 'wiki-toolbar#wrapLines',
                           wiki_toolbar_prefix_param: format(button[:prefix], lang: lang),
                           wiki_toolbar_suffix_param: format(button[:suffix], lang: lang)
                         })
            end
          end
        )
      end
    end

    def table_menu(_button)
      tag.table(class: 'table-generator', role: 'grid',
                data: {
                  action: 'click->wiki-toolbar#closeMenu keydown.esc->wiki-toolbar#closeMenu ' \
                          'mouseover->wiki-toolbar#highlightTable focusin->wiki-toolbar#highlightTable'
                }) do
        @view.safe_join(
          (1..TABLE_MENU_ROWS).map do |row|
            tag.tr do
              @view.safe_join(
                (1..TABLE_MENU_COLS).map do |col|
                  tag.td do
                    tag.button(type: 'button', title: "#{col}×#{row}", aria: {label: "#{col}×#{row}"},
                               data: {
                                 action: 'wiki-toolbar#insertTable',
                                 wiki_toolbar_cols_param: col,
                                 wiki_toolbar_rows_param: row
                               })
                  end
                end
              )
            end
          end
        )
      end
    end

    def code_languages
      User.current.pref.toolbar_language_options.to_s.split(',')
    end

    def keyboard_actions
      @keyboard_actions ||= begin
        keys = buttons.filter_map {|button| button[:shortcut] if button.is_a?(Hash)}
        actions = keys.flat_map do |key|
          %w[ctrl meta].map {|modifier| "keydown.#{modifier}+#{key}->wiki-toolbar#shortcut"}
        end
        actions += %w[ctrl meta].map {|modifier| "keydown.#{modifier}+shift+p@window->wiki-toolbar#togglePreview"}
        actions.join(' ')
      end
    end
  end
end
