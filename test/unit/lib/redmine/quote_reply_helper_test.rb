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

class QuoteReplyHelperTest < ActionView::TestCase
  include ERB::Util
  include Redmine::QuoteReply::Helper

  def test_quote_reply
    with_locale 'en' do
      url = quoted_issue_path(issues(:issues_001))

      a_tag = quote_reply(url, '#issue_description_wiki')
      assert_includes a_tag, %|onclick="#{h "quoteReply('/issues/1/quoted', '#issue_description_wiki', 'common_mark'); return false;"}"|
      assert_includes a_tag, %|class="icon icon-comment"|
      assert_not_includes a_tag, 'title='

      # When icon_only is true
      a_tag = quote_reply(url, '#issue_description_wiki', icon_only: true)
      assert_includes a_tag, %|title="Quote"|
    end
  end
end
