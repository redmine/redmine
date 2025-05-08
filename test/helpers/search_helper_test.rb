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

class SearchHelperTest < Redmine::HelperTest
  include SearchHelper
  include ERB::Util

  def test_highlight_single_token
    assert_equal 'This is a <span class="highlight token-0">token</span>.',
                 highlight_tokens('This is a token.', %w(token))
  end

  def test_highlight_multiple_tokens
    assert_equal(
      'This is a <span class="highlight token-0">token</span> and ' \
        '<span class="highlight token-1">another</span> ' \
        '<span class="highlight token-0">token</span>.',
      highlight_tokens('This is a token and another token.', %w(token another))
    )
  end

  def test_highlight_should_not_exceed_maximum_length
    s = (('1234567890' * 100) + ' token ') * 100
    r = highlight_tokens(s, %w(token))
    assert r.include?('<span class="highlight token-0">token</span>')
    assert r.length <= 1300
  end

  def test_highlight_multibyte
    s = ('й' * 200) + ' token ' + ('й' * 200)
    r = highlight_tokens(s, %w(token))
    assert_equal(
      ('й' * 45) + ' ... ' + ('й' * 44) +
        ' <span class="highlight token-0">token</span> ' +
        ('й' * 44) + ' ... ' + ('й' * 45),
      r
    )
  end

  def test_issues_filter_path
    # rubocop:disable Layout/LineLength
    assert_equal(
      '/issues?f[]=status_id&f[]=any_searchable&f[]=project_id&op[any_searchable]=*~&op[project_id]==&op[status_id]=*&set_filter=1&sort=updated_on:desc&v[any_searchable][]=recipe&v[project_id][]=mine',
      Addressable::URI.unencode(issues_filter_path('recipe', projects_scope: 'my_projects'))
    )
    assert_equal(
      '/issues?f[]=status_id&f[]=any_searchable&f[]=project_id&op[any_searchable]=*~&op[project_id]==&op[status_id]=*&set_filter=1&sort=updated_on:desc&v[any_searchable][]=recipe&v[project_id][]=bookmarks',
      Addressable::URI.unencode(issues_filter_path('recipe', projects_scope: 'bookmarks'))
    )
    assert_equal(
      '/issues?f[]=status_id&f[]=any_searchable&op[any_searchable]=*~&op[status_id]=*&set_filter=1&sort=updated_on:desc&v[any_searchable][]=recipe',
      Addressable::URI.unencode(issues_filter_path('recipe', projects_scope: 'all'))
    )
    # f[]=subject
    assert_equal(
      '/issues?f[]=status_id&f[]=subject&op[status_id]=*&op[subject]=*~&set_filter=1&sort=updated_on:desc&v[subject][]=recipe',
      Addressable::URI.unencode(issues_filter_path('recipe', projects_scope: 'all', titles_only: '1'))
    )
    # op[subject]=~ (contains)
    assert_equal(
      '/issues?f[]=status_id&f[]=subject&op[status_id]=*&op[subject]=~&set_filter=1&sort=updated_on:desc&v[subject][]=recipe',
      Addressable::URI.unencode(issues_filter_path('recipe', projects_scope: 'all', titles_only: '1', all_words: ''))
    )
    # op[status_id]=o (open)
    assert_equal(
      '/issues?f[]=status_id&f[]=subject&op[status_id]=o&op[subject]=*~&set_filter=1&sort=updated_on:desc&v[subject][]=recipe',
      Addressable::URI.unencode(issues_filter_path('recipe', projects_scope: 'all', titles_only: '1', open_issues: '1'))
    )
    # rubocop:enable Layout/LineLength
  end
end
