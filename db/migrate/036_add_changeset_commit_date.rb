class AddChangesetCommitDate < ActiveRecord::Migration[4.2]
  def self.up
    add_column :changesets, :commit_date, :date
    Changeset.update_all "commit_date = committed_on"
  end

  def self.down
    remove_column :changesets, :commit_date
  end
end
