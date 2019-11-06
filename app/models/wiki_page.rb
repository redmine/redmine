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

require 'diff'

class WikiPage < ActiveRecord::Base
  include Redmine::SafeAttributes

  belongs_to :wiki
  has_one :content, :class_name => 'WikiContent', :foreign_key => 'page_id', :dependent => :destroy
  has_one :content_without_text, lambda {without_text.readonly}, :class_name => 'WikiContent', :foreign_key => 'page_id'

  acts_as_attachable :delete_permission => :delete_wiki_pages_attachments
  acts_as_tree :dependent => :nullify, :order => 'title'

  acts_as_watchable
  acts_as_event :title => Proc.new {|o| "#{l(:label_wiki)}: #{o.title}"},
                :description => :text,
                :datetime => :created_on,
                :url => Proc.new {|o| {:controller => 'wiki', :action => 'show', :project_id => o.wiki.project, :id => o.title}}

  acts_as_searchable :columns => ['title', "#{WikiContent.table_name}.text"],
                     :scope => joins(:content, {:wiki => :project}),
                     :preload => [:content, {:wiki => :project}],
                     :permission => :view_wiki_pages,
                     :project_key => "#{Wiki.table_name}.project_id"

  attr_accessor :redirect_existing_links
  attr_writer   :deleted_attachment_ids

  validates_presence_of :title
  validates_format_of :title, :with => /\A[^,\.\/\?\;\|\s]*\z/
  validates_uniqueness_of :title, :scope => :wiki_id, :case_sensitive => false
  validates_length_of :title, maximum: 255
  validates_associated :content

  validate :validate_parent_title
  before_destroy :delete_redirects
  before_save :handle_rename_or_move, :update_wiki_start_page
  after_save :handle_children_move, :delete_selected_attachments

  # eager load information about last updates, without loading text
  scope :with_updated_on, lambda { preload(:content_without_text) }

  # Wiki pages that are protected by default
  DEFAULT_PROTECTED_PAGES = %w(sidebar)

  safe_attributes 'parent_id', 'parent_title', 'title', 'redirect_existing_links', 'wiki_id',
                  :if => lambda {|page, user| page.new_record? || user.allowed_to?(:rename_wiki_pages, page.project)}

  safe_attributes 'is_start_page',
                  :if => lambda {|page, user| user.allowed_to?(:manage_wiki, page.project)}

  safe_attributes 'deleted_attachment_ids',
                  :if => lambda {|page, user| page.attachments_deletable?(user)}

  def initialize(attributes=nil, *args)
    super
    if new_record? && DEFAULT_PROTECTED_PAGES.include?(title.to_s.downcase)
      self.protected = true
    end
  end

  def visible?(user=User.current)
    !user.nil? && user.allowed_to?(:view_wiki_pages, project)
  end

  def title=(value)
    value = Wiki.titleize(value)
    write_attribute(:title, value)
  end

  def safe_attributes=(attrs, user=User.current)
    if attrs.respond_to?(:to_unsafe_hash)
      attrs = attrs.to_unsafe_hash
    end

    return unless attrs.is_a?(Hash)
    attrs = attrs.deep_dup

    # Project and Tracker must be set before since new_statuses_allowed_to depends on it.
    if (w_id = attrs.delete('wiki_id')) && safe_attribute?('wiki_id')
      if (w = Wiki.find_by_id(w_id)) && w.project && user.allowed_to?(:rename_wiki_pages, w.project)
        self.wiki = w
      end
    end

    super attrs, user
  end

  # Manages redirects if page is renamed or moved
  def handle_rename_or_move
    if !new_record? && (title_changed? || wiki_id_changed?)
      # Update redirects that point to the old title
      WikiRedirect.where(:redirects_to => title_was, :redirects_to_wiki_id => wiki_id_was).each do |r|
        r.redirects_to = title
        r.redirects_to_wiki_id = wiki_id
        (r.title == r.redirects_to && r.wiki_id == r.redirects_to_wiki_id) ? r.destroy : r.save
      end
      # Remove redirects for the new title
      WikiRedirect.where(:wiki_id => wiki_id, :title => title).delete_all
      # Create a redirect to the new title
      unless redirect_existing_links == "0"
        WikiRedirect.create(
          :wiki_id => wiki_id_was, :title => title_was,
          :redirects_to_wiki_id => wiki_id, :redirects_to => title
        )
      end
    end
    if !new_record? && wiki_id_changed? && parent.present?
      unless parent.wiki_id == wiki_id
        self.parent_id = nil
      end
    end
  end
  private :handle_rename_or_move

  # Moves child pages if page was moved
  def handle_children_move
    if !new_record? && saved_change_to_wiki_id?
      children.each do |child|
        child.wiki_id = wiki_id
        child.redirect_existing_links = redirect_existing_links
        unless child.save
          WikiPage.where(:id => child.id).update_all :parent_id => nil
        end
      end
    end
  end
  private :handle_children_move

  # Deletes redirects to this page
  def delete_redirects
    WikiRedirect.where(:redirects_to_wiki_id => wiki_id, :redirects_to => title).delete_all
  end

  def pretty_title
    WikiPage.pretty_title(title)
  end

  def content_for_version(version=nil)
    if content
      result = content.versions.find_by_version(version.to_i) if version
      result ||= content
      result
    end
  end

  def diff(version_to=nil, version_from=nil)
    version_to = version_to ? version_to.to_i : self.content.version
    content_to = content.versions.find_by_version(version_to)
    content_from = version_from ? content.versions.find_by_version(version_from.to_i) : content_to.try(:previous)
    return nil unless content_to && content_from

    if content_from.version > content_to.version
      content_to, content_from = content_from, content_to
    end

    (content_to && content_from) ? WikiDiff.new(content_to, content_from) : nil
  end

  def annotate(version=nil)
    version = version ? version.to_i : self.content.version
    c = content.versions.find_by_version(version)
    c ? WikiAnnotate.new(c) : nil
  end

  def self.pretty_title(str)
    (str && str.is_a?(String)) ? str.tr('_', ' ') : str
  end

  def project
    wiki.try(:project)
  end

  def text
    content.text if content
  end

  def updated_on
    content_attribute(:updated_on)
  end

  def version
    content_attribute(:version)
  end

  # Returns true if usr is allowed to edit the page, otherwise false
  def editable_by?(usr)
    !protected? || usr.allowed_to?(:protect_wiki_pages, wiki.project)
  end

  def attachments_deletable?(usr=User.current)
    editable_by?(usr) && super(usr)
  end

  def parent_title
    @parent_title || (self.parent && self.parent.pretty_title)
  end

  def parent_title=(t)
    @parent_title = t
    parent_page = t.blank? ? nil : self.wiki.find_page(t)
    self.parent = parent_page
  end

  def is_start_page
    if @is_start_page.nil?
      @is_start_page = wiki.try(:start_page) == title_was
    end
    @is_start_page
  end

  def is_start_page=(arg)
    @is_start_page = arg == '1' || arg == true
  end

  def update_wiki_start_page
    if is_start_page
      wiki.update_attribute :start_page, title
    end
  end
  private :update_wiki_start_page

  # Saves the page and its content if text was changed
  # Return true if the page was saved
  def save_with_content(content)
    ret = nil
    transaction do
      ret = save
      if content.text_changed?
        begin
          self.content = content
        rescue ActiveRecord::RecordNotSaved
          ret = false
        end
      end
      raise ActiveRecord::Rollback unless ret
    end
    ret
  end

  def deleted_attachment_ids
    Array(@deleted_attachment_ids).map(&:to_i)
  end

  def delete_selected_attachments
    if deleted_attachment_ids.present?
      objects = attachments.where(:id => deleted_attachment_ids.map(&:to_i))
      attachments.delete(objects)
    end
  end

  protected

  def validate_parent_title
    errors.add(:parent_title, :invalid) if !@parent_title.blank? && parent.nil?
    errors.add(:parent_title, :circular_dependency) if parent && (parent == self || parent.ancestors.include?(self))
    if parent_id_changed? && parent && (parent.wiki_id != wiki_id)
      errors.add(:parent_title, :not_same_project)
    end
  end

  private

  def content_attribute(name)
    (association(:content).loaded? ? content : content_without_text).try(name)
  end
end

class WikiDiff < Redmine::Helpers::Diff
  attr_reader :content_to, :content_from

  def initialize(content_to, content_from)
    @content_to = content_to
    @content_from = content_from
    super(content_to.text, content_from.text)
  end
end

class WikiAnnotate
  attr_reader :lines, :content

  def initialize(content)
    @content = content
    current = content
    current_lines = current.text.split(/\r?\n/)
    @lines = current_lines.collect {|t| [nil, nil, t]}
    positions = []
    current_lines.size.times {|i| positions << i}
    while current.previous
      d = current.previous.text.split(/\r?\n/).diff(current.text.split(/\r?\n/)).diffs.flatten
      d.each_slice(3) do |s|
        sign, line = s[0], s[1]
        if sign == '+' && positions[line] && positions[line] != -1
          if @lines[positions[line]][0].nil?
            @lines[positions[line]][0] = current.version
            @lines[positions[line]][1] = current.author
          end
        end
      end
      d.each_slice(3) do |s|
        sign, line = s[0], s[1]
        if sign == '-'
          positions.insert(line, -1)
        else
          positions[line] = nil
        end
      end
      positions.compact!
      # Stop if every line is annotated
      break unless @lines.detect { |line| line[0].nil? }
      current = current.previous
    end
    @lines.each { |line|
      line[0] ||= current.version
      # if the last known version is > 1 (eg. history was cleared), we don't know the author
      line[1] ||= current.author if current.version == 1
    }
  end
end
