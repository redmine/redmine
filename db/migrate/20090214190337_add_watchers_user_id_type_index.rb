class AddWatchersUserIdTypeIndex < ActiveRecord::Migration[4.2]
  def self.up
    add_index :watchers, [:user_id, :watchable_type], :name => :watchers_user_id_type
  end

  def self.down
    remove_index :watchers, :name => :watchers_user_id_type
  end
end
