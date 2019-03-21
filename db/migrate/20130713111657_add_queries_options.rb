class AddQueriesOptions < ActiveRecord::Migration[4.2]
  def up
    add_column :queries, :options, :text
  end

  def down
    remove_column :queries, :options
  end
end
