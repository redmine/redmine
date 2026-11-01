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

module WikiToolbarHelper
  # Returns a textarea with the wiki toolbar
  #
  # Options:
  # * :preview_url - URL used to preview the text (default: preview_text_path)
  # * any other option is passed to textarea_tag
  def wiki_textarea_tag(name, content = nil, options = {})
    options = options.dup
    preview_url = options.delete(:preview_url) || preview_text_path
    options = wiki_textarea_options(options)
    wiki_toolbar(options[:id] || sanitize_to_id(name), preview_url: preview_url) do
      textarea_tag(name, content, options)
    end
  end

  # Renders the wiki toolbar around the textarea returned by the block. The
  # textarea must be rendered with the options returned by
  # #wiki_textarea_options.
  def wiki_toolbar(field_id, preview_url: preview_text_path, &)
    field = capture(&)
    return field unless Redmine::WikiToolbar.buttons(Setting.text_formatting)

    heads_for_wiki_formatter
    render(partial: 'wiki_toolbar/toolbar', locals: {field_id: field_id, field: field, preview_url: preview_url})
  end

  # Returns the data attributes of a toolbar button
  def wiki_toolbar_button_data(name)
    data =
      if Redmine::WikiToolbar::MENUS.include?(name)
        {action: 'wiki-toolbar#toggleMenu', wiki_toolbar_menu_param: name}
      elsif name == 'help'
        {action: 'wiki-toolbar#help'}
      else
        {action: 'wiki-toolbar#apply', wiki_toolbar_button_param: name}
      end
    data[:wiki_toolbar_shortcut] = Redmine::WikiToolbar::SHORTCUTS[name] if Redmine::WikiToolbar::SHORTCUTS[name]
    data
  end

  # Adds the CSS class and the data attributes used by the wiki textareas
  def wiki_textarea_options(options)
    options.merge(
      class: ['wiki-edit', options[:class]].compact.join(' ').split.uniq.join(' '),
      data: wiki_textarea_stimulus_attributes.merge(wiki_toolbar_target: 'field').merge(options[:data] || {})
    )
  end
end
