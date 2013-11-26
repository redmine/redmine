class AddRepositoriesCreatedOn < ActiveRecord::Migration
  def up
    add_column :repositories, :created_on, :timestamp
  end

  def down
    remove_column :repositories, :created_on
  end
end
