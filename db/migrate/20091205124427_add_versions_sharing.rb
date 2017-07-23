class AddVersionsSharing < ActiveRecord::Migration[4.2]
  def self.up
    add_column :versions, :sharing, :string, :default => 'none', :null => false
    add_index :versions, :sharing
  end

  def self.down
    remove_column :versions, :sharing
  end
end
