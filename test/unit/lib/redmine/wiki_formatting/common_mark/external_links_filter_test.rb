# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

require File.expand_path('../../../../../../test_helper', __FILE__)

if Object.const_defined?(:CommonMarker)
  require 'redmine/wiki_formatting/common_mark/external_links_filter'

  class Redmine::WikiFormatting::CommonMark::ExternalLinksFilterTest < ActiveSupport::TestCase
    def filter(html)
      Redmine::WikiFormatting::CommonMark::ExternalLinksFilter.to_html(html, @options)
    end

    def setup
      @options = { }
    end

    def test_external_links_should_have_external_css_class
      assert_equal %(<a href="http://example.net/" class="external">link</a>), filter(%(<a href="http://example.net/">link</a>))
    end

    def test_locals_links_should_not_have_external_css_class
      assert_equal %(<a href="/">home</a>), filter(%(<a href="/">home</a>))
      assert_equal %(<a href="relative">relative</a>), filter(%(<a href="relative">relative</a>))
      assert_equal %(<a href="#anchor">anchor</a>), filter(%(<a href="#anchor">anchor</a>))
    end

    def test_mailto_links_should_have_email_class
      assert_equal %(<a href="mailto:user@example.org" class="email">user</a>), filter(%(<a href="mailto:user@example.org">user</a>))
    end

    def test_malformed_uri_should_not_cause_exception
      assert_nothing_raised do
        filter(%(<a href="http://example.com/foo#bar#">Malformed URI</a>))
      end
    end

    def test_external_links_with_target_get_rel_noopener
      assert_equal(
        %(<a target="_blank" href="http://example.net/" class="external" rel="noopener">link</a>),
        filter(%(<a target="_blank" href="http://example.net/">link</a>))
      )
      assert_equal(
        %(<a target="_blank" href="http://example.net/" rel="nofollow noopener" class="external">link</a>),
        filter(%(<a target="_blank" href="http://example.net/" rel="nofollow">link</a>))
      )
    end
  end
end
