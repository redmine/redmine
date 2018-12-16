class AddAuthorIdToTimeEntries < ActiveRecord::Migration[5.1]
  def up
    add_column :time_entries, :author_id, :integer, :default => nil, :after => :project_id
    # Copy existing user_id to author_id
    TimeEntry.update_all('author_id = user_id')
  end

  def down
    remove_column :time_entries, :author_id
  end
end
