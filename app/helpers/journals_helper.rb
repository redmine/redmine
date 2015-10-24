# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

  def render_notes(issue, journal, options={})
    content = ''
    editable = User.current.logged? && (User.current.allowed_to?(:edit_issue_notes, issue.project) || (journal.user == User.current && User.current.allowed_to?(:edit_own_issue_notes, issue.project)))
    links = []
    if !journal.notes.blank?
      links << link_to(image_tag('comment.png'),
                       {:controller => 'journals', :action => 'new', :id => issue, :journal_id => journal},
                       :remote => true,
                       :method => 'post',
                       :title => l(:button_quote)) if options[:reply_links]
      links << link_to_in_place_notes_editor(image_tag('edit.png'), "journal-#{journal.id}-notes",
                                             { :controller => 'journals', :action => 'edit', :id => journal, :format => 'js' },
                                                :title => l(:button_edit)) if editable
    end
    content << content_tag('div', links.join(' ').html_safe, :class => 'contextual') unless links.empty?
    content << textilizable(journal, :notes)
    css_classes = "wiki"
    css_classes << " editable" if editable
    content_tag('div', content.html_safe, :id => "journal-#{journal.id}-notes", :class => css_classes)
  end

  def link_to_in_place_notes_editor(text, field_id, url, options={})
    onclick = "$.ajax({url: '#{url_for(url)}', type: 'get'}); return false;"
    link_to text, '#', options.merge(:onclick => onclick)
  end
end
