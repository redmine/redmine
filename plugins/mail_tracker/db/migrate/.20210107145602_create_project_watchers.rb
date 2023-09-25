class CreateProjectWatchers < ActiveRecord::Migration[6.1]
  def change
    create_table :project_watchers do |t|
      t.references :project
      t.references :group
    end

    # add_index :project_watchers, :project_id
    # add_index :project_watchers, :group_id
  end
end
