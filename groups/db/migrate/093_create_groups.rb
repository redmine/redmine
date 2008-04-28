class CreateGroups < ActiveRecord::Migration
  def self.up
    create_table :groups do |t|
      t.column :name, :string, :null => false
    end
  end

  def self.down
    drop_table :groups
  end
end
