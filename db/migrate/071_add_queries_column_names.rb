class AddQueriesColumnNames < ActiveRecord::Migration[4.2]
  def self.up
    add_column :queries, :column_names, :text
  end

  def self.down
    remove_column :queries, :column_names
  end
end
