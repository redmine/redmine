# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
# Copyright (C) 2007  Patrick Aljord patcito@ŋmail.com
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

require 'redmine/scm/adapters/git_adapter'

class Repository::Git < Repository
  validates_presence_of :url

  safe_attributes 'report_last_commit'

  def self.human_attribute_name(attribute_key_name, *args)
    attr_name = attribute_key_name.to_s
    attr_name = 'path_to_repository' if attr_name == 'url'
    super(attr_name, *args)
  end

  def self.scm_adapter_class
    Redmine::Scm::Adapters::GitAdapter
  end

  def self.scm_name
    'Git'
  end

  def report_last_commit
    return false if extra_info.nil?

    v = extra_info["extra_report_last_commit"]
    return false if v.nil?

    v.to_s != '0'
  end

  def report_last_commit=(arg)
    merge_extra_info "extra_report_last_commit" => arg
  end

  def supports_directory_revisions?
    true
  end

  def supports_revision_graph?
    true
  end

  def repo_log_encoding
    'UTF-8'
  end

  # Returns the identifier for the given git changeset
  def self.changeset_identifier(changeset)
    changeset.scmid
  end

  # Returns the readable identifier for the given git changeset
  def self.format_changeset_identifier(changeset)
    changeset.revision[0, 8]
  end

  def branches
    scm.branches
  end

  def tags
    scm.tags
  end

  def default_branch
    scm.default_branch
  rescue => e
    logger.error "git: error during get default branch: #{e.message}"
    nil
  end

  def find_changeset_by_name(name)
    return if name.blank?

    changesets.find_by(:revision => name.to_s) ||
      changesets.where('scmid LIKE ?', "#{name}%").first
  end

  def scm_entries(path=nil, identifier=nil)
    scm.entries(path, identifier, :report_last_commit => report_last_commit)
  end
  protected :scm_entries

  # With SCMs that have a sequential commit numbering,
  # such as Subversion and Mercurial,
  # Redmine is able to be clever and only fetch changesets
  # going forward from the most recent one it knows about.
  #
  # However, Git does not have a sequential commit numbering.
  #
  # In order to fetch only new adding revisions,
  # Redmine needs to save "heads".
  #
  # In Git and Mercurial, revisions are not in date order.
  # Redmine Mercurial fixed issues.
  #    * Redmine Takes Too Long On Large Mercurial Repository
  #      http://www.redmine.org/issues/3449
  #    * Sorting for changesets might go wrong on Mercurial repos
  #      http://www.redmine.org/issues/3567
  #
  # Database revision column is text, so Redmine can not sort by revision.
  # Mercurial has revision number, and revision number guarantees revision order.
  # Redmine Mercurial model stored revisions ordered by database id to database.
  # So, Redmine Mercurial model can use correct ordering revisions.
  #
  # Redmine Mercurial adapter uses "hg log -r 0:tip --limit 10"
  # to get limited revisions from old to new.
  # But, Git 1.7.3.4 does not support --reverse with -n or --skip.
  #
  # The repository can still be fully reloaded by calling #clear_changesets
  # before fetching changesets (eg. for offline resync)
  def fetch_changesets
    scm_brs = branches
    return if scm_brs.blank?

    h = extra_info.dup || {}
    repo_heads = scm_brs.map(&:scmid)
    prev_db_heads = h["heads"].dup || []
    prev_db_heads += heads_from_branches_hash if prev_db_heads.empty?
    return if prev_db_heads.sort == repo_heads.sort

    h["db_consistent"]  ||= {}
    if ! changesets.exists?
      h["db_consistent"]["ordering"] = 1
      merge_extra_info(h)
      self.save
    elsif ! h["db_consistent"].has_key?("ordering")
      h["db_consistent"]["ordering"] = 0
      merge_extra_info(h)
      self.save
    end
    save_revisions(prev_db_heads, repo_heads)
  end

  def save_revisions(prev_db_heads, repo_heads)
    h = {}
    opts = {}
    opts[:reverse]  = true
    opts[:excludes] = prev_db_heads
    opts[:includes] = repo_heads

    revisions = scm.revisions('', nil, nil, opts)
    return if revisions.blank?

    # Make the search for existing revisions in the database in a more sufficient manner
    #
    # Git branch is the reference to the specific revision.
    # Git can *delete* remote branch and *re-push* branch.
    #
    #  $ git push remote :branch
    #  $ git push remote branch
    #
    # After deleting branch, revisions remain in repository until "git gc".
    # On git 1.7.2.3, default pruning date is 2 weeks.
    # So, "git log --not deleted_branch_head_revision" return code is 0.
    #
    # After re-pushing branch, "git log" returns revisions which are saved in database.
    # So, Redmine needs to scan revisions and database every time.
    #
    # This is replacing the one-after-one queries.
    # Find all revisions, that are in the database, and then remove them
    # from the revision array.
    # Then later we won't need any conditions for db existence.
    # Query for several revisions at once, and remove them
    # from the revisions array, if they are there.
    # Do this in chunks, to avoid eventual memory problems
    # (in case of tens of thousands of commits).
    # If there are no revisions (because the original code's algorithm filtered them),
    # then this part will be stepped over.
    # We make queries, just if there is any revision.
    limit = 100
    offset = 0
    revisions_copy = revisions.clone # revisions will change
    while offset < revisions_copy.size
      scmids = revisions_copy.slice(offset, limit).map(&:scmid)
      recent_changesets_slice = changesets.where(:scmid => scmids)
      # Subtract revisions that redmine already knows about
      recent_revisions = recent_changesets_slice.map(&:scmid)
      revisions.reject!{|r| recent_revisions.include?(r.scmid)}
      offset += limit
    end
    revisions.each do |rev|
      transaction do
        # There is no search in the db for this revision, because above we ensured,
        # that it's not in the db.
        save_revision(rev)
      end
    end
    h["heads"] = repo_heads.dup
    merge_extra_info(h)
    save(:validate => false)
  end
  private :save_revisions

  def save_revision(rev)
    parents = (rev.parents || []).filter_map{|rp| find_changeset_by_name(rp)}
    changeset =
      Changeset.create(
        :repository   => self,
        :revision     => rev.identifier,
        :scmid        => rev.scmid,
        :committer    => rev.author,
        :committed_on => rev.time,
        :comments     => rev.message,
        :parents      => parents
      )
    rev.paths.each {|change| changeset.create_change(change)} unless changeset.new_record?
    changeset
  end
  private :save_revision

  def heads_from_branches_hash
    h = extra_info.dup || {}
    h["branches"] ||= {}
    h['branches'].map{|br, hs| hs['last_scmid']}
  end

  def latest_changesets(path, rev, limit=10)
    revisions = scm.revisions(path, nil, rev, :limit => limit, :all => false)
    return [] if revisions.blank?

    changesets.where(:scmid => revisions.map(&:scmid)).to_a
  end

  def clear_extra_info_of_changesets
    return if extra_info.nil?

    v = extra_info["extra_report_last_commit"]
    write_attribute(:extra_info, nil)
    merge_extra_info({"extra_report_last_commit" => v})
    save(:validate => false)
  end
  private :clear_extra_info_of_changesets

  def clear_changesets
    super
    clear_extra_info_of_changesets
  end
  private :clear_changesets
end
