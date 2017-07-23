class AddWorkflowsType < ActiveRecord::Migration[4.2]
  def up
    add_column :workflows, :type, :string, :limit => 30
  end

  def down
    remove_column :workflows, :type
  end
end
