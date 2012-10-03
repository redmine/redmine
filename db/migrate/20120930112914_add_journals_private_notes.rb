class AddJournalsPrivateNotes < ActiveRecord::Migration
  def up
    add_column :journals, :private_notes, :boolean, :default => false, :null => false
  end

  def down
    remove_column :journals, :private_notes
  end
end
