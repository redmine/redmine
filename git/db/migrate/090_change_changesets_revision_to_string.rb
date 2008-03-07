class ChangeChangesetsRevisionToString < ActiveRecord::Migration
  def self.up
    change_column :changesets, :revision, :string
  end

  def self.down
    change_column :changesets, :revision, :integer
  end
end
