class AddChangesetsUserId < ActiveRecord::Migration[4.2]
  def self.up
    add_column :changesets, :user_id, :integer, :default => nil
  end

  def self.down
    remove_column :changesets, :user_id
  end
end
