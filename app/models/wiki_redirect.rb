# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class WikiRedirect < ActiveRecord::Base
  belongs_to :wiki

  validates_presence_of :wiki_id, :title, :redirects_to
  validates_length_of :title, :redirects_to, :maximum => 255

  before_save :set_redirects_to_wiki_id

  def target_page
    wiki = Wiki.find_by_id(redirects_to_wiki_id)
    if wiki
      wiki.find_page(redirects_to, :with_redirect => false)
    end
  end

  private

  def set_redirects_to_wiki_id
    self.redirects_to_wiki_id ||= wiki_id
  end
end
