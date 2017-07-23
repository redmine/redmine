class AddIssuesClosedOn < ActiveRecord::Migration[4.2]
  def up
    add_column :issues, :closed_on, :datetime, :default => nil
  end

  def down
    remove_column :issues, :closed_on
  end
end
