class AddMessagesSticky < ActiveRecord::Migration[4.2]
  def self.up
    add_column :messages, :sticky, :integer, :default => 0
  end

  def self.down
    remove_column :messages, :sticky
  end
end
