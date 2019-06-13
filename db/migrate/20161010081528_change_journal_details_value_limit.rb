class ChangeJournalDetailsValueLimit < ActiveRecord::Migration[4.2]
  def up
    if Redmine::Database.mysql?
      max_size = 16.megabytes
      change_column :journal_details, :value, :text, :limit => max_size
      change_column :journal_details, :old_value, :text, :limit => max_size
    end
  end

  def down
    # no-op
  end
end
