class AddMissingIndexesToNews < ActiveRecord::Migration[4.2]
  def self.up
    add_index :news, :author_id
  end

  def self.down
    remove_index :news, :author_id
  end
end
