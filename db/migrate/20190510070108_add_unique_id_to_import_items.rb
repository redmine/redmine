class AddUniqueIdToImportItems < ActiveRecord::Migration[5.2]
  def change
    change_table :import_items do |t|
      t.string "unique_id"
      t.index ["import_id", "unique_id"]
    end
  end
end
