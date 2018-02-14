class CreateImports < ActiveRecord::Migration
  def change
    create_table :imports do |t|
      t.string :type
      t.integer :user_id, :null => false
      t.string :filename
      t.text :settings
      t.integer :total_items
      t.boolean :finished, :null => false, :default => false
      t.timestamps :null => false
    end
  end
end
