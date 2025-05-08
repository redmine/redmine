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

class HelpController < ApplicationController
  def show_wiki_syntax
    type = params[:type].nil? ? "" : "#{params[:type]}_"

    lang = current_language.to_s
    template = "help/wiki_syntax/#{Setting.text_formatting}/#{lang}/wiki_syntax_#{type}#{Setting.text_formatting}"
    unless lookup_context.exists?(template)
      lang = "en"
    end
    render template: "help/wiki_syntax/#{Setting.text_formatting}/#{lang}/wiki_syntax_#{type}#{Setting.text_formatting}", layout: nil
  end

  def show_code_highlighting
    @available_lexers = Rouge::Lexer.all.sort_by(&:tag)
    render template: "help/wiki_syntax/code_highlighting_languages", layout: nil
  end
end
