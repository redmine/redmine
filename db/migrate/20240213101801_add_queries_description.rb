class AddQueriesDescription < ActiveRecord::Migration[6.1]
  def up
    add_column :queries, :description, :string, :after => :name
  end

  def down
    remove_column :queries, :description
  end
end
