class AddQueriesSortCriteria < ActiveRecord::Migration[4.2]
  def self.up
    add_column :queries, :sort_criteria, :text
  end

  def self.down
    remove_column :queries, :sort_criteria
  end
end
