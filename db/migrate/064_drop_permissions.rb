class DropPermissions < ActiveRecord::Migration[4.2]
  def self.up
    drop_table :permissions
    drop_table :permissions_roles
  end

  def self.down
    raise IrreversibleMigration
  end
end
