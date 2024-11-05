class CreateCategories < Rails.version < '5.1' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def self.up
    create_table :kb_categories do |t|
      t.column :title, :string, :null => false
      t.column :description, :text
      t.timestamps
    end
  end

  def self.down
    drop_table :kb_categories
  end
end
