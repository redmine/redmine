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

require 'redmine/scm/adapters/subversion_adapter'

class Repository::Subversion < Repository
  validates_presence_of :url
  validates_format_of :url, :with => %r{\A(http|https|svn(\+[^\s:\/\\]+)?|file):\/\/.+}i

  def self.scm_adapter_class
    Redmine::Scm::Adapters::SubversionAdapter
  end

  def self.scm_name
    'Subversion'
  end

  def supports_directory_revisions?
    true
  end

  def repo_log_encoding
    'UTF-8'
  end

  def latest_changesets(path, rev, limit=10)
    revisions = scm.revisions(path, rev, nil, :limit => limit)
    if revisions
      identifiers = revisions.filter_map(&:identifier)
      changesets.where(:revision => identifiers).reorder("committed_on DESC").includes(:repository, :user).to_a
    else
      []
    end
  end

  # Returns a path relative to the url of the repository
  def relative_path(path)
    path.gsub(Regexp.new("^/?#{Regexp.escape(relative_url)}"), '')
  end

  def fetch_changesets
    scm_info = scm.info
    if scm_info
      # latest revision found in database
      db_revision = latest_changeset ? latest_changeset.revision.to_i : 0
      # latest revision in the repository
      scm_revision = scm_info.lastrev.identifier.to_i
      if db_revision < scm_revision
        logger.debug "Fetching changesets for repository #{url}" if logger && logger.debug?
        identifier_from = db_revision + 1
        while (identifier_from <= scm_revision)
          # loads changesets by batches of 200
          identifier_to = [identifier_from + 199, scm_revision].min
          revisions = scm.revisions('', identifier_to, identifier_from, :with_paths => true)
          unless revisions.nil?
            revisions.reverse_each do |revision|
              transaction do
                changeset = Changeset.create(:repository   => self,
                                             :revision     => revision.identifier,
                                             :committer    => revision.author,
                                             :committed_on => revision.time,
                                             :comments     => revision.message)
                unless changeset.new_record?
                  revision.paths.each do |change|
                    changeset.create_change(change)
                  end
                end
              end
            end
          end
          identifier_from = identifier_to + 1
        end
      end
    end
  end

  protected

  def load_entries_changesets(entries)
    return unless entries

    entries_with_identifier =
      entries.select {|entry| entry.lastrev && entry.lastrev.identifier.present?}
    identifiers = entries_with_identifier.filter_map {|entry| entry.lastrev.identifier}.uniq
    if identifiers.any?
      changesets_by_identifier =
        changesets.where(:revision => identifiers).
          includes(:user, :repository).group_by(&:revision)
      entries_with_identifier.each do |entry|
        if m = changesets_by_identifier[entry.lastrev.identifier]
          entry.changeset = m.first
        end
      end
    end
  end

  private

  # Returns the relative url of the repository
  # Eg: root_url = file:///var/svn/foo
  #     url      = file:///var/svn/foo/bar
  #     => returns /bar
  def relative_url
    @relative_url ||= url.gsub(Regexp.new("^#{Regexp.escape(root_url || scm.root_url)}", Regexp::IGNORECASE), '')
  end
end
