class AddIssuesIsPrivate < ActiveRecord::Migration[4.2]
  def self.up
    add_column :issues, :is_private, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :issues, :is_private
  end
end
