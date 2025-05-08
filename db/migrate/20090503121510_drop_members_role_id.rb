class DropMembersRoleId < ActiveRecord::Migration[4.2]
  def self.up
    remove_column :members, :role_id
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
