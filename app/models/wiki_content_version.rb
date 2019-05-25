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

require 'zlib'

class WikiContentVersion < ActiveRecord::Base
  belongs_to :page, :class_name => 'WikiPage'
  belongs_to :author, :class_name => 'User'

  acts_as_event :title => Proc.new {|o| "#{l(:label_wiki_edit)}: #{o.page.title} (##{o.version})"},
                :description => :comments,
                :datetime => :updated_on,
                :type => 'wiki-page',
                :group => :page,
                :url => Proc.new {|o| {:controller => 'wiki', :action => 'show', :project_id => o.page.wiki.project, :id => o.page.title, :version => o.version}}

  acts_as_activity_provider :type => 'wiki_edits',
                            :timestamp => "#{table_name}.updated_on",
                            :author_key => "#{table_name}.author_id",
                            :permission => :view_wiki_edits,
                            :scope => select("#{table_name}.updated_on, #{table_name}.comments, " +
                                             "#{table_name}.version, #{WikiPage.table_name}.title, " +
                                             "#{table_name}.page_id, #{table_name}.author_id, " +
                                             "#{table_name}.id").
                                      joins("LEFT JOIN #{WikiPage.table_name} ON #{WikiPage.table_name}.id = #{table_name}.page_id " +
                                            "LEFT JOIN #{Wiki.table_name} ON #{Wiki.table_name}.id = #{WikiPage.table_name}.wiki_id " +
                                            "LEFT JOIN #{Project.table_name} ON #{Project.table_name}.id = #{Wiki.table_name}.project_id")

  after_destroy :page_update_after_destroy

  def text=(plain)
    case Setting.wiki_compression
    when 'gzip'
    begin
      self.data = Zlib::Deflate.deflate(plain, Zlib::BEST_COMPRESSION)
      self.compression = 'gzip'
    rescue
      self.data = plain
      self.compression = ''
    end
    else
      self.data = plain
      self.compression = ''
    end
    plain
  end

  def text
    @text ||= begin
      str = case compression
            when 'gzip'
              Zlib::Inflate.inflate(data)
            else
              # uncompressed data
              data
            end
      str.force_encoding("UTF-8")
      str
    end
  end

  def project
    page.project
  end

  def attachments
    page.nil? ? [] : page.attachments
  end

  # Return true if the content is the current page content
  def current_version?
    page.content.version == self.version
  end

  # Returns the previous version or nil
  def previous
    @previous ||= WikiContentVersion.
      reorder(version: :desc).
      includes(:author).
      where("wiki_content_id = ? AND version < ?", wiki_content_id, version).first
  end

  # Returns the next version or nil
  def next
    @next ||= WikiContentVersion.
      reorder(version: :asc).
      includes(:author).
      where("wiki_content_id = ? AND version > ?", wiki_content_id, version).first
  end

  private

  # Updates page's content if the latest version is removed
  # or destroys the page if it was the only version
  def page_update_after_destroy
    latest = page.content.versions.reorder(version: :desc).first
    if latest && page.content.version != latest.version
      raise ActiveRecord::Rollback unless page.content.revert_to!(latest)
    elsif latest.nil?
      raise ActiveRecord::Rollback unless page.destroy
    end
  end
end
