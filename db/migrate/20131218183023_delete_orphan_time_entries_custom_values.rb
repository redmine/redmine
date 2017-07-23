class DeleteOrphanTimeEntriesCustomValues < ActiveRecord::Migration[4.2]
  def up
    CustomValue.where("customized_type = ? AND NOT EXISTS (SELECT 1 FROM #{TimeEntry.table_name} t WHERE t.id = customized_id)", "TimeEntry").delete_all
  end

  def down
    # nop
  end
end
