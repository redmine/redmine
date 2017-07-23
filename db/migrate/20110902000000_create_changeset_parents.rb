class CreateChangesetParents < ActiveRecord::Migration[4.2]
  def self.up
    create_table :changeset_parents, :id => false do |t|
      t.column :changeset_id, :integer, :null => false
      t.column :parent_id, :integer, :null => false
    end
    add_index :changeset_parents, [:changeset_id], :unique => false, :name => :changeset_parents_changeset_ids
    add_index :changeset_parents, [:parent_id], :unique => false, :name => :changeset_parents_parent_ids
  end

  def self.down
     drop_table :changeset_parents
  end
end
