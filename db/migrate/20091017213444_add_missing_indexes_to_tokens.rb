class AddMissingIndexesToTokens < ActiveRecord::Migration[4.2]
  def self.up
    add_index :tokens, :user_id
  end

  def self.down
    remove_index :tokens, :user_id
  end
end
