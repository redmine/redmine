class AddMissingIndexesToWatchers < ActiveRecord::Migration[4.2]
  def self.up
    add_index :watchers, :user_id
    add_index :watchers, [:watchable_id, :watchable_type]
  end

  def self.down
    remove_index :watchers, :user_id
    remove_index :watchers, :column => [:watchable_id, :watchable_type]
  end
end
