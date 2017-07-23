class AddChangesBranch < ActiveRecord::Migration[4.2]
  def self.up
    add_column :changes, :branch, :string
  end

  def self.down
    remove_column :changes, :branch
  end
end
