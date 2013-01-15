class ChangeChangesetsRevisionToString < ActiveRecord::Migration
  def self.up
    # Some backends (eg. SQLServer 2012) do not support changing the type
    # of an indexed column so the index needs to be dropped first
    # BUT this index is renamed with some backends (at least SQLite3) for
    # some (unknown) reasons, thus we check for the other name as well
    # so we don't end up with 2 identical indexes
    if index_exists? :changesets, [:repository_id, :revision], :name => :changesets_repos_rev
      remove_index  :changesets, :name => :changesets_repos_rev
    end
    if index_exists? :changesets, [:repository_id, :revision], :name => :altered_changesets_repos_rev
      remove_index  :changesets, :name => :altered_changesets_repos_rev
    end

    change_column :changesets, :revision, :string, :null => false

    add_index :changesets, [:repository_id, :revision], :unique => true, :name => :changesets_repos_rev
  end

  def self.down
    if index_exists? :changesets, :changesets_repos_rev
      remove_index  :changesets, :name => :changesets_repos_rev
    end
    if index_exists? :changesets, [:repository_id, :revision], :name => :altered_changesets_repos_rev
      remove_index  :changesets, :name => :altered_changesets_repos_rev
    end

    change_column :changesets, :revision, :integer, :null => false

    add_index :changesets, [:repository_id, :revision], :unique => true, :name => :changesets_repos_rev
  end
end
