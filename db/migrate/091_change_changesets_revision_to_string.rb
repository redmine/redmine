class ChangeChangesetsRevisionToString < ActiveRecord::Migration
  def self.up
    remove_index  :changesets, :name => :changesets_repos_rev
    change_column :changesets, :revision, :string, :null => false
    add_index :changesets, [:repository_id, :revision], :unique => true, :name => :changesets_repos_rev
  end

  def self.down
    remove_index  :changesets, :name => :changesets_repos_rev
    change_column :changesets, :revision, :integer, :null => false
    add_index :changesets, [:repository_id, :revision], :unique => true, :name => :changesets_repos_rev
  end
end
