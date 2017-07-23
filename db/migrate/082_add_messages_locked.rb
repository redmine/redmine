class AddMessagesLocked < ActiveRecord::Migration[4.2]
  def self.up
    add_column :messages, :locked, :boolean, :default => false
  end

  def self.down
    remove_column :messages, :locked
  end
end
