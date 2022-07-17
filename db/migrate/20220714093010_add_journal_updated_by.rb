class AddJournalUpdatedBy < ActiveRecord::Migration[5.2]
  def up
    add_column :journals, :updated_by_id, :integer, :default => nil, :after => :updated_on
  end

  def down
    remove_column :journals, :updated_by_id
  end
end
