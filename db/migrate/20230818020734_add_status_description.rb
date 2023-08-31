class AddStatusDescription < ActiveRecord::Migration[6.1]
  def up
    add_column :issue_statuses, :description, :string, :after => :name
  end

  def down
    remove_column :issue_statuses, :description
  end
end
