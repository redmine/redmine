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

require 'redmine/scm/adapters/mercurial_adapter'

class Repository::Mercurial < Repository
  # sort changesets by revision number
  has_many :changesets,
           lambda {order("#{Changeset.table_name}.id DESC")},
           :foreign_key => 'repository_id'

  attr_protected        :root_url
  validates_presence_of :url

  # number of changesets to fetch at once
  FETCH_AT_ONCE = 100

  def self.human_attribute_name(attribute_key_name, *args)
    attr_name = attribute_key_name.to_s
    if attr_name == "url"
      attr_name = "path_to_repository"
    end
    super(attr_name, *args)
  end

  def self.scm_adapter_class
    Redmine::Scm::Adapters::MercurialAdapter
  end

  def self.scm_name
    'Mercurial'
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

  # Returns the readable identifier for the given mercurial changeset
  def self.format_changeset_identifier(changeset)
    "#{changeset.revision}:#{changeset.scmid[0, 12]}"
  end

  # Returns the identifier for the given Mercurial changeset
  def self.changeset_identifier(changeset)
    changeset.scmid
  end

  def diff_format_revisions(cs, cs_to, sep=':')
    super(cs, cs_to, ' ')
  end

  def modify_entry_lastrev_identifier(entry)
    if entry.lastrev && entry.lastrev.identifier
      entry.lastrev.identifier = scmid_for_inserting_db(entry.lastrev.identifier)
    end
  end
  private :modify_entry_lastrev_identifier

  def entry(path=nil, identifier=nil)
    entry = scm.entry(path, identifier)
    return nil if entry.nil?
    modify_entry_lastrev_identifier(entry)
    entry
  end

  def scm_entries(path=nil, identifier=nil)
    entries = scm.entries(path, identifier)
    return nil if entries.nil?
    entries.each {|entry| modify_entry_lastrev_identifier(entry)}
    entries
  end
  protected :scm_entries

  # Finds and returns a revision with a number or the beginning of a hash
  def find_changeset_by_name(name)
    return nil if name.blank?
    s = name.to_s
    if /[^\d]/ =~ s or s.size > 8
      cs = changesets.where(:scmid => s).first
    else
      cs = changesets.where(:revision => s).first
    end
    return cs if cs
    changesets.where('scmid LIKE ?', "#{s}%").first
  end

  # Returns the latest changesets for +path+; sorted by revision number
  #
  # Because :order => 'id DESC' is defined at 'has_many',
  # there is no need to set 'order'.
  # But, MySQL test fails.
  # Sqlite3 and PostgreSQL pass.
  # Is this MySQL bug?
  def latest_changesets(path, rev, limit=10)
    changesets.
      includes(:user).
      where(latest_changesets_cond(path, rev, limit)).
      references(:user).
      limit(limit).
      order("#{Changeset.table_name}.id DESC").
      to_a
  end

  def is_short_id_in_db?
    return @is_short_id_in_db unless @is_short_id_in_db.nil?
    cs = changesets.first
    @is_short_id_in_db = (!cs.nil? && cs.scmid.length != 40)
  end
  private :is_short_id_in_db?

  def scmid_for_inserting_db(scmid)
    is_short_id_in_db? ? scmid[0, 12] : scmid
  end

  def nodes_in_branch(rev, branch_limit)
    scm.nodes_in_branch(rev, :limit => branch_limit).collect do |b|
      scmid_for_inserting_db(b)
    end
  end

  def tag_scmid(rev)
    scmid = scm.tagmap[rev]
    scmid.nil? ? nil : scmid_for_inserting_db(scmid)
  end

  def latest_changesets_cond(path, rev, limit)
    cond, args = [], []
    if scm.branchmap.member? rev
      # Mercurial named branch is *stable* in each revision.
      # So, named branch can be stored in database.
      # Mercurial provides *bookmark* which is equivalent with git branch.
      # But, bookmark is not implemented.
      cond << "#{Changeset.table_name}.scmid IN (?)"
      # Revisions in root directory and sub directory are not equal.
      # So, in order to get correct limit, we need to get all revisions.
      # But, it is very heavy.
      # Mercurial does not treat directory.
      # So, "hg log DIR" is very heavy.
      branch_limit = path.blank? ? limit : ( limit * 5 )
      args << nodes_in_branch(rev, branch_limit)
    elsif last = rev ? find_changeset_by_name(tag_scmid(rev) || rev) : nil
      cond << "#{Changeset.table_name}.id <= ?"
      args << last.id
    end
    unless path.blank?
      cond << "EXISTS (SELECT * FROM #{Change.table_name}
                 WHERE #{Change.table_name}.changeset_id = #{Changeset.table_name}.id
                 AND (#{Change.table_name}.path = ?
                       OR #{Change.table_name}.path LIKE ? ESCAPE ?))"
      args << path.with_leading_slash
      args << "#{path.with_leading_slash.gsub(%r{[%_\\]}) { |s| "\\#{s}" }}/%" << '\\'
    end
    [cond.join(' AND '), *args] unless cond.empty?
  end
  private :latest_changesets_cond

  def fetch_changesets
    return if scm.info.nil?
    scm_rev = scm.info.lastrev.revision.to_i
    db_rev  = latest_changeset ? latest_changeset.revision.to_i : -1
    return unless db_rev < scm_rev  # already up-to-date

    logger.debug "Fetching changesets for repository #{url}" if logger
    (db_rev + 1).step(scm_rev, FETCH_AT_ONCE) do |i|
      scm.each_revision('', i, [i + FETCH_AT_ONCE - 1, scm_rev].min) do |re|
        transaction do
          parents = (re.parents || []).collect do |rp|
            find_changeset_by_name(scmid_for_inserting_db(rp))
          end.compact
          cs = Changeset.create(:repository   => self,
                                :revision     => re.revision,
                                :scmid        => scmid_for_inserting_db(re.scmid),
                                :committer    => re.author,
                                :committed_on => re.time,
                                :comments     => re.message,
                                :parents      => parents)
          unless cs.new_record?
            re.paths.each do |e|
              if from_revision = e[:from_revision]
                e[:from_revision] = scmid_for_inserting_db(from_revision)
              end
              cs.create_change(e)
            end
          end
        end
      end
    end
  end
end
