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

require_relative '../../../../../test_helper'

if Object.const_defined?(:Commonmarker)
  require 'redmine/wiki_formatting/common_mark/alerts_icons_scrubber'

  class Redmine::WikiFormatting::CommonMark::AlertsIconsFilterTest < ActiveSupport::TestCase
    include Redmine::I18n

    def format(markdown)
      Redmine::WikiFormatting::CommonMark::MarkdownFilter.new(markdown, Redmine::WikiFormatting::CommonMark::PIPELINE_CONFIG).call
    end

    def filter(html)
      fragment = Redmine::WikiFormatting::HtmlParser.parse(html)
      scrubber = Redmine::WikiFormatting::CommonMark::AlertsIconsScrubber.new
      fragment.scrub!(scrubber)
      fragment.to_s
    end

    def setup
      @options = { }
    end

    def teardown
      set_language_if_valid 'en'
    end

    def test_should_render_alert_blocks_with_localized_labels
      set_language_if_valid 'de'
      text = <<~MD
        > [!note]
        > This is a note.
      MD

      html = filter(format(text))
      expected = %r{<span class="icon-label">#{I18n.t('label_alert_note')}</span>}
      assert_match expected, html
    end

    def test_should_not_translate_title_if_overridden
      set_language_if_valid 'de'
      text = <<~MD
        > [!note] Custom Note Title
        > This is a note.
      MD
      html = filter(format(text))
      assert_match %r{<span class="icon-label">Custom Note Title</span>}, html
    end
  end
end
