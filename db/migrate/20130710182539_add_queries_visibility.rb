class AddQueriesVisibility < ActiveRecord::Migration[4.2]
  def up
    add_column :queries, :visibility, :integer, :default => 0
    Query.where(:is_public => true).update_all(:visibility => 2)
    remove_column :queries, :is_public
  end

  def down
    add_column :queries, :is_public, :boolean, :default => true, :null => false
    Query.where('visibility <> ?', 2).update_all(:is_public => false)
    remove_column :queries, :visibility
  end
end
