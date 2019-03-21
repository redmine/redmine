class AddMissingIndexesToMemberRoles < ActiveRecord::Migration[4.2]
  def self.up
    add_index :member_roles, :member_id
    add_index :member_roles, :role_id
  end

  def self.down
    remove_index :member_roles, :member_id
    remove_index :member_roles, :role_id
  end
end
