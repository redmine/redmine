class AddParentIdToCategories < Rails.version < '5.1' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def self.up
    add_column :kb_categories, :parent_id, :int
  end

  def self.down
    remove_column :kb_categories, :parent_id
  end
end
