class RemoveUsersMail < ActiveRecord::Migration
  def self.up
    remove_column :users, :mail
  end

  def self.down
    raise IrreversibleMigration
  end
end
