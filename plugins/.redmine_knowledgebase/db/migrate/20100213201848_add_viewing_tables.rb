class AddViewingTables < Rails.version < '5.1' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def self.up
    ActiveRecord::Base.create_viewings_table
  end

  def self.down
    ActiveRecord::Base.drop_viewings_table
  end
end
