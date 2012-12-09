class AddQueriesType < ActiveRecord::Migration
  def up
    add_column :queries, :type, :string
  end

  def down
    remove_column :queries, :type
  end
end
