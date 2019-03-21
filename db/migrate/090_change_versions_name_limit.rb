class ChangeVersionsNameLimit < ActiveRecord::Migration[4.2]
  def self.up
    change_column :versions, :name, :string, :limit => nil
  end

  def self.down
    change_column :versions, :name, :string, :limit => 30
  end
end
