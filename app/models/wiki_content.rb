# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class WikiContent < ActiveRecord::Base
  self.locking_column = 'version'
  belongs_to :page, :class_name => 'WikiPage'
  belongs_to :author, :class_name => 'User'
  validates_presence_of :text
  validates_length_of :comments, :maximum => 1024, :allow_nil => true
  attr_protected :id

  acts_as_versioned

  after_save :send_notification

  scope :without_text, lambda {select(:id, :page_id, :version, :updated_on)}

  def visible?(user=User.current)
    page.visible?(user)
  end

  def project
    page.project
  end

  def attachments
    page.nil? ? [] : page.attachments
  end

  def notified_users
    project.notified_users.reject {|user| !visible?(user)}
  end

  # Returns the mail addresses of users that should be notified
  def recipients
    notified_users.collect(&:mail)
  end

  # Return true if the content is the current page content
  def current_version?
    true
  end

  class Version
    belongs_to :page, :class_name => '::WikiPage'
    belongs_to :author, :class_name => '::User'
    attr_protected :data

    acts_as_event :title => Proc.new {|o| "#{l(:label_wiki_edit)}: #{o.page.title} (##{o.version})"},
                  :description => :comments,
                  :datetime => :updated_on,
                  :type => 'wiki-page',
                  :group => :page,
                  :url => Proc.new {|o| {:controller => 'wiki', :action => 'show', :project_id => o.page.wiki.project, :id => o.page.title, :version => o.version}}

    acts_as_activity_provider :type => 'wiki_edits',
                              :timestamp => "#{WikiContent.versioned_table_name}.updated_on",
                              :author_key => "#{WikiContent.versioned_table_name}.author_id",
                              :permission => :view_wiki_edits,
                              :scope => select("#{WikiContent.versioned_table_name}.updated_on, #{WikiContent.versioned_table_name}.comments, " +
                                               "#{WikiContent.versioned_table_name}.#{WikiContent.version_column}, #{WikiPage.table_name}.title, " +
                                               "#{WikiContent.versioned_table_name}.page_id, #{WikiContent.versioned_table_name}.author_id, " +
                                               "#{WikiContent.versioned_table_name}.id").
                                        joins("LEFT JOIN #{WikiPage.table_name} ON #{WikiPage.table_name}.id = #{WikiContent.versioned_table_name}.page_id " +
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

    # Return true if the content is the current page content
    def current_version?
      page.content.version == self.version
    end

    # Returns the previous version or nil
    def previous
      @previous ||= WikiContent::Version.
        reorder('version DESC').
        includes(:author).
        where("wiki_content_id = ? AND version < ?", wiki_content_id, version).first
    end

    # Returns the next version or nil
    def next
      @next ||= WikiContent::Version.
        reorder('version ASC').
        includes(:author).
        where("wiki_content_id = ? AND version > ?", wiki_content_id, version).first
    end

    private

    # Updates page's content if the latest version is removed
    # or destroys the page if it was the only version
    def page_update_after_destroy
      latest = page.content.versions.reorder("#{self.class.table_name}.version DESC").first
      if latest && page.content.version != latest.version
        raise ActiveRecord::Rollback unless page.content.revert_to!(latest)
      elsif latest.nil?
        raise ActiveRecord::Rollback unless page.destroy
      end
    end
  end

  private

  def send_notification
    # new_record? returns false in after_save callbacks
    if id_changed?
      if Setting.notified_events.include?('wiki_content_added')
        Mailer.wiki_content_added(self).deliver
      end
    elsif text_changed?
      if Setting.notified_events.include?('wiki_content_updated')
        Mailer.wiki_content_updated(self).deliver
      end
    end
  end
end
