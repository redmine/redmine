class AddChangesRevision < ActiveRecord::Migration[4.2]
  def self.up
    add_column :changes, :revision, :string
  end

  def self.down
    remove_column :changes, :revision
  end
end
