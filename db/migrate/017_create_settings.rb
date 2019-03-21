class CreateSettings < ActiveRecord::Migration[4.2]
  def self.up
    create_table :settings, :force => true do |t|
      t.column "name", :string, :limit => 30, :default => "", :null => false
      t.column "value", :text
    end
  end

  def self.down
    drop_table :settings
  end
end
