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

require 'redmine/scm/adapters/cvs_adapter'
require 'digest/sha1'

class Repository::Cvs < Repository
  validates_presence_of :url, :root_url, :log_encoding

  safe_attributes(
    'root_url',
    :if => lambda {|repository, user| repository.new_record?})

  def self.human_attribute_name(attribute_key_name, *args)
    attr_name = attribute_key_name.to_s
    if attr_name == "root_url"
      attr_name = "cvsroot"
    elsif attr_name == "url"
      attr_name = "cvs_module"
    end
    super(attr_name, *args)
  end

  def self.scm_adapter_class
    Redmine::Scm::Adapters::CvsAdapter
  end

  def self.scm_name
    'CVS'
  end

  def entry(path=nil, identifier=nil)
    rev = identifier.nil? ? nil : changesets.find_by_revision(identifier)
    scm.entry(path, rev.nil? ? nil : rev.committed_on)
  end

  def scm_entries(path=nil, identifier=nil)
    rev = nil
    if ! identifier.nil?
      rev = changesets.find_by_revision(identifier)
      return nil if rev.nil?
    end
    entries = scm.entries(path, rev.nil? ? nil : rev.committed_on)
    if entries
      entries.each do |entry|
        if ( ! entry.lastrev.nil? ) && ( ! entry.lastrev.revision.nil? )
          change =
            filechanges.where(
              :revision => entry.lastrev.revision,
              :path => scm.with_leading_slash(entry.path)
            ).first
          if change
            entry.lastrev.identifier = change.changeset.revision
            entry.lastrev.revision   = change.changeset.revision
            entry.lastrev.author     = change.changeset.committer
            # entry.lastrev.branch     = change.branch
          end
        end
      end
    end
    entries
  end
  protected :scm_entries

  def cat(path, identifier=nil)
    rev = nil
    if ! identifier.nil?
      rev = changesets.find_by_revision(identifier)
      return nil if rev.nil?
    end
    scm.cat(path, rev.nil? ? nil : rev.committed_on)
  end

  def annotate(path, identifier=nil)
    rev = nil
    if ! identifier.nil?
      rev = changesets.find_by_revision(identifier)
      return nil if rev.nil?
    end
    scm.annotate(path, rev.nil? ? nil : rev.committed_on)
  end

  def diff(path, rev, rev_to)
    # convert rev to revision. CVS can't handle changesets here
    diff=[]
    changeset_from = changesets.find_by_revision(rev)
    if rev_to.to_i > 0
      changeset_to = changesets.find_by_revision(rev_to)
    end
    changeset_from.filechanges.each do |change_from|
      revision_from = nil
      revision_to   = nil
      if path.nil? || (change_from.path.starts_with? scm.with_leading_slash(path))
        revision_from = change_from.revision
      end
      if revision_from
        if changeset_to
          changeset_to.filechanges.each do |change_to|
            revision_to = change_to.revision if change_to.path == change_from.path
          end
        end
        unless revision_to
          revision_to = scm.get_previous_revision(revision_from)
        end
        file_diff = scm.diff(change_from.path, revision_from, revision_to)
        diff = diff + file_diff unless file_diff.nil?
      end
    end
    return diff
  end

  def fetch_changesets
    # some nifty bits to introduce a commit-id with cvs
    # natively cvs doesn't provide any kind of changesets,
    # there is only a revision per file.
    # we now take a guess using the author, the commitlog and the commit-date.

    # last one is the next step to take. the commit-date is not equal for all
    # commits in one changeset. cvs update the commit-date when the *,v file was touched. so
    # we use a small delta here, to merge all changes belonging to _one_ changeset
    time_delta  = 10.seconds
    fetch_since = latest_changeset ? latest_changeset.committed_on : nil
    transaction do
      tmp_rev_num = 1
      scm.revisions('', fetch_since, nil, :log_encoding => repo_log_encoding) do |revision|
        # only add the change to the database, if it doen't exists. the cvs log
        # is not exclusive at all.
        tmp_time = revision.time.clone
        unless filechanges.
                 find_by_path_and_revision(
                   scm.with_leading_slash(revision.paths[0][:path]),
                   revision.paths[0][:revision]
                 )
          cmt = Changeset.normalize_comments(revision.message, repo_log_encoding)
          author_utf8 = Changeset.to_utf8(revision.author, repo_log_encoding)
          cs =
            changesets.where(
              :committed_on => (tmp_time - time_delta)..(tmp_time + time_delta),
              :committer    => author_utf8,
              :comments     => cmt
            ).first
          # create a new changeset....
          unless cs
            # we use a temporary revision number here (just for inserting)
            # later on, we calculate a continuous positive number
            tmp_time2 = tmp_time.clone.gmtime
            branch    = revision.paths[0][:branch]
            scmid     = branch + "-" + tmp_time2.strftime("%Y%m%d-%H%M%S")
            cs = Changeset.create(:repository   => self,
                                  :revision     => "tmp#{tmp_rev_num}",
                                  :scmid        => scmid,
                                  :committer    => revision.author,
                                  :committed_on => tmp_time,
                                  :comments     => revision.message)
            tmp_rev_num += 1
          end
          # convert CVS-File-States to internal Action-abbreviations
          # default action is (M)odified
          action = "M"
          if revision.paths[0][:action] == "Exp" && revision.paths[0][:revision] == "1.1"
            action = "A" # add-action always at first revision (= 1.1)
          elsif revision.paths[0][:action] == "dead"
            action = "D" # dead-state is similar to Delete
          end
          Change.create(
            :changeset => cs,
            :action    => action,
            :path      => scm.with_leading_slash(revision.paths[0][:path]),
            :revision  => revision.paths[0][:revision],
            :branch    => revision.paths[0][:branch]
          )
        end
      end

      # Renumber new changesets in chronological order
      Changeset.
        order('committed_on ASC, id ASC').
        where("repository_id = ? AND revision LIKE 'tmp%'", id).
        each do |changeset|
          changeset.update_attribute :revision, next_revision_number
        end
    end
    @current_revision_number = nil
  end

  protected

  # Overrides Repository#validate_repository_path to validate
  # against root_url attribute.
  def validate_repository_path(attribute=:root_url)
    super(attribute)
  end

  private

  # Returns the next revision number to assign to a CVS changeset
  def next_revision_number
    # Need to retrieve existing revision numbers to sort them as integers
    sql = "SELECT revision FROM #{Changeset.table_name} " \
          "WHERE repository_id = #{id} AND revision NOT LIKE 'tmp%'"
    @current_revision_number ||= (self.class.connection.select_values(sql).collect(&:to_i).max || 0)
    @current_revision_number += 1
  end
end
