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

class Wiki < ActiveRecord::Base
  include Redmine::SafeAttributes
  belongs_to :project
  has_many :pages, lambda {order(Arel.sql('LOWER(title)').asc)}, :class_name => 'WikiPage', :dependent => :destroy
  has_many :redirects, :class_name => 'WikiRedirect'

  acts_as_watchable

  validates_presence_of :start_page
  validates_format_of :start_page, :with => /\A[^,\.\/\?\;\|\:]*\z/
  validates_length_of :start_page, maximum: 255

  before_destroy :delete_redirects

  safe_attributes 'start_page'

  def visible?(user=User.current)
    !user.nil? && user.allowed_to?(:view_wiki_pages, project)
  end

  # Returns the wiki page that acts as the sidebar content
  # or nil if no such page exists
  def sidebar
    @sidebar ||= find_page('Sidebar', :with_redirect => false)
  end

  # find the page with the given title
  # if page doesn't exist, return a new page
  def find_or_new_page(title)
    title = start_page if title.blank?
    find_page(title) || WikiPage.new(:wiki => self, :title => Wiki.titleize(title))
  end

  # find the page with the given title
  def find_page(title, options = {})
    @page_found_with_redirect = false
    title = start_page if title.blank?
    title = Wiki.titleize(title)
    page = pages.find_by("LOWER(title) = LOWER(?)", title)
    if page.nil? && options[:with_redirect] != false
      # search for a redirect
      redirect = redirects.where("LOWER(title) = LOWER(?)", title).first
      if redirect
        page = redirect.target_page
        @page_found_with_redirect = true
      end
    end
    page
  end

  # Returns true if the last page was found with a redirect
  def page_found_with_redirect?
    @page_found_with_redirect
  end

  # Deletes all redirects from/to the wiki
  def delete_redirects
    WikiRedirect.where(:wiki_id => id).delete_all
    WikiRedirect.where(:redirects_to_wiki_id => id).delete_all
  end

  # Finds a page by title
  # The given string can be of one of the forms: "title" or "project:title"
  # Examples:
  #   Wiki.find_page("bar", project => foo)
  #   Wiki.find_page("foo:bar")
  def self.find_page(title, options = {})
    project = options[:project]
    if title.to_s =~ %r{^([^\:]+)\:(.*)$}
      project_identifier, title = $1, $2
      project = Project.find_by_identifier(project_identifier) || Project.find_by_name(project_identifier)
    end
    if project && project.wiki
      page = project.wiki.find_page(title)
      if page && page.content
        page
      end
    end
  end

  def self.create_default(project)
    create(:project => project, :start_page => 'Wiki')
  end

  # turn a string into a valid page title
  def self.titleize(title)
    # replace spaces with _ and remove unwanted caracters
    title = title.gsub(/\s+/, '_').delete(',./?;|:') if title
    # upcase the first letter
    title = (title.slice(0..0).upcase + (title.slice(1..-1) || '')) if title
    title
  end
end
