class ChangeMembersUsersAssociationToPolymorphic < ActiveRecord::Migration
  def self.up
    add_column :members, :principal_type, :string
    add_column :members, :principal_id, :integer
    add_column :members, :inherited_from, :integer
    Member.update_all "principal_type = 'User', principal_id = user_id"
    remove_column :members, :user_id
    add_index :members, [:principal_type, :principal_id], :name => :members_principal
  end

  def self.down
    # Remove inherited and groups memberships
    Member.delete_all "inherited_from IS NOT NULL OR principal_type = 'Group'"
    add_column :members, :user_id, :integer, :default => 0, :null => false
    Member.update_all "user_id = principal_id"
    remove_column :members, :principal_type
    remove_column :members, :principal_id
    remove_column :members, :inherited_from
  end
end
