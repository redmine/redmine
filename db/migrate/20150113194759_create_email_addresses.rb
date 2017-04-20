class CreateEmailAddresses < ActiveRecord::Migration
  def change
    create_table :email_addresses do |t|
      t.column :user_id, :integer, :null => false
      t.column :address, :string, :null => false
      t.column :is_default, :boolean, :null => false, :default => false
      t.column :notify, :boolean, :null => false, :default => true
      t.column :created_on, :timestamp, :null => false
      t.column :updated_on, :timestamp, :null => false
    end
  end
end
