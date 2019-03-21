class AddQueriesType < ActiveRecord::Migration[4.2]
  def up
    add_column :queries, :type, :string
  end

  def down
    remove_column :queries, :type
  end
end
