class ExtendSettingsName < ActiveRecord::Migration[4.2]
  def self.up
    change_column :settings, :name, :string, :limit => 255, :default => '', :null => false
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
