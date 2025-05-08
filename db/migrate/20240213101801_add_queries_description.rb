class AddQueriesDescription < ActiveRecord::Migration[7.1]
  def up
    add_column :queries, :description, :string
  end

  def down
    remove_column :queries, :description
  end
end
