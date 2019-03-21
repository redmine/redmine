class AddEnumerationsPositionName < ActiveRecord::Migration[4.2]
  def up
    add_column :enumerations, :position_name, :string, :limit => 30
  end

  def down
    remove_column :enumerations, :position_name
  end
end
