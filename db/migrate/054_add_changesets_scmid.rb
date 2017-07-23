class AddChangesetsScmid < ActiveRecord::Migration[4.2]
  def self.up
    add_column :changesets, :scmid, :string
  end

  def self.down
    remove_column :changesets, :scmid
  end
end
