class AddMissingIndexesToJournals < ActiveRecord::Migration[4.2]
  def self.up
    add_index :journals, :user_id
    add_index :journals, :journalized_id
  end

  def self.down
    remove_index :journals, :user_id
    remove_index :journals, :journalized_id
  end
end
