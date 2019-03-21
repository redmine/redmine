class AddMissingIndexesToQueries < ActiveRecord::Migration[4.2]
  def self.up
    add_index :queries, :project_id
    add_index :queries, :user_id
  end

  def self.down
    remove_index :queries, :project_id
    remove_index :queries, :user_id
  end
end
