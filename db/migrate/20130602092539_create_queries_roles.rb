class CreateQueriesRoles < ActiveRecord::Migration
  def self.up
    create_table :queries_roles, :id => false do |t|
      t.column :query_id, :integer, :null => false
      t.column :role_id, :integer, :null => false
    end
    add_index :queries_roles, [:query_id, :role_id], :unique => true, :name => :queries_roles_ids
  end

  def self.down
    drop_table :queries_roles
  end
end
