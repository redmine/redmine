class ChangeChangesetsCommitterLimit < ActiveRecord::Migration[4.2]
  def self.up
    change_column :changesets, :committer, :string, :limit => nil
  end

  def self.down
    change_column :changesets, :committer, :string, :limit => 30
  end
end
