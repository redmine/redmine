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

module JournalsHelper

  # Returns the attachments of a journal that are displayed as thumbnails
  def journal_thumbnail_attachments(journal)
    ids = journal.details.select {|d| d.property == 'attachment' && d.value.present?}.map(&:prop_key)
    ids.any? ? Attachment.where(:id => ids).select(&:thumbnailable?) : []
  end

  # Returns the action links for an issue journal
  def render_journal_actions(issue, journal, options={})
    links = []
    if journal.notes.present?
      if options[:reply_links]
        indice = journal.indice || @journal.issue.visible_journals_with_index.find{|j| j.id == @journal.id}.indice
        links << link_to(l(:button_quote),
                         quoted_issue_path(issue, :journal_id => journal, :journal_indice => indice),
                         :remote => true,
                         :method => 'post',
                         :title => l(:button_quote),
                         :class => 'icon-only icon-comment'
                        )
      end
      if journal.editable_by?(User.current)
        links << link_to(l(:button_edit),
                         edit_journal_path(journal),
                         :remote => true,
                         :method => 'get',
                         :title => l(:button_edit),
                         :class => 'icon-only icon-edit'
                        )
        links << link_to(l(:button_delete),
                         journal_path(journal, :journal => {:notes => ""}),
                         :remote => true,
                         :method => 'put', :data => {:confirm => l(:text_are_you_sure)},
                         :title => l(:button_delete),
                         :class => 'icon-only icon-del'
                        )
      end
    end
    safe_join(links, ' ')
  end

  def render_notes(issue, journal, options={})
    content_tag('div', textilizable(journal, :notes), :id => "journal-#{journal.id}-notes", :class => "wiki")
  end

  def render_private_notes_indicator(journal)
    content = journal.private_notes? ? l(:field_is_private) : ''
    css_classes = journal.private_notes? ? 'badge badge-private private' : ''
    content_tag('span', content.html_safe, :id => "journal-#{journal.id}-private_notes", :class => css_classes)
  end
end
