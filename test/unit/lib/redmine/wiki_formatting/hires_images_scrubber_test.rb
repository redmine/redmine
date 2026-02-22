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

class Redmine::WikiFormatting::HiresImagesScrubberTest < ActiveSupport::TestCase
  def filter(html)
    fragment = Redmine::WikiFormatting::HtmlParser.parse(html)
    scrubber = Redmine::WikiFormatting::HiresImagesScrubber.new
    fragment.scrub!(scrubber)
    fragment.to_s
  end

  def test_should_add_srcset_for_hires_images
    html = '<img src="/attachments/download/1/image@2x.png">'
    expected = '<img src="/attachments/download/1/image@2x.png" srcset="/attachments/download/1/image@2x.png 2x">'
    assert_equal expected, filter(html)
  end

  def test_should_not_add_srcset_for_non_hires_images
    html = '<img src="/attachments/download/1/image.png">'
    assert_equal html, filter(html)
  end
end
