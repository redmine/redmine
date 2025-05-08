class AddJournalUpdatedOn < ActiveRecord::Migration[5.2]
  def up
    add_column :journals, :updated_on, :datetime, :after => :created_on
    Journal.update_all('updated_on = created_on')
  end

  def down
    remove_column :journals, :updated_on
  end
end
