class CreateEmailAddresses < ActiveRecord::Migration[4.2]
  def change
    create_table :email_addresses do |t|
      t.column :user_id, :integer, :null => false
      t.column :address, :string, :null => false
      t.column :is_default, :boolean, :null => false, :default => false
      t.column :notify, :boolean, :null => false, :default => true
      t.column :created_on, :datetime, :null => false
      t.column :updated_on, :datetime, :null => false
    end
  end
end
