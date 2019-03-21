class AddMissingIndexesToDocuments < ActiveRecord::Migration[4.2]
  def self.up
    add_index :documents, :category_id
  end

  def self.down
    remove_index :documents, :category_id
  end
end
