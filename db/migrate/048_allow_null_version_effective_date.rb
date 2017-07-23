class AllowNullVersionEffectiveDate < ActiveRecord::Migration[4.2]
  def self.up
    change_column :versions, :effective_date, :date, :default => nil, :null => true
  end

  def self.down
    raise IrreversibleMigration
  end
end
