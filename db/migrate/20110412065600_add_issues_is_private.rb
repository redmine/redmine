class AddIssuesIsPrivate < ActiveRecord::Migration
  def self.up
    add_column :issues, :is_private, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :issues, :is_private
  end
end
