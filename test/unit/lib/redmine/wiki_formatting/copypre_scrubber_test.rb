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

require_relative '../../../../test_helper'

class Redmine::WikiFormatting::CopypreScrubberTest < ActiveSupport::TestCase
  def filter(html)
    fragment = Redmine::WikiFormatting::HtmlParser.parse(html)
    scrubber = Redmine::WikiFormatting::CopypreScrubber.new
    fragment.scrub!(scrubber)
    fragment.to_s
  end

  test 'should add copy button to all pre blocks' do
    input = <<~HTML
      <pre>Block 1</pre>
      <pre>Block 2</pre>
    HTML

    output = filter(input)

    # Check that each pre block is wrapped and has a copy button
    assert_equal 2, output.scan('<div class="pre-wrapper" data-controller="clipboard">').size
    assert_equal 2, output.scan('class="copy-pre-content-link icon-only"').size
  end
end
