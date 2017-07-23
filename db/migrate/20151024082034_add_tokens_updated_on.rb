class AddTokensUpdatedOn < ActiveRecord::Migration[4.2]
  def self.up
    add_column :tokens, :updated_on, :timestamp
    Token.update_all("updated_on = created_on")
  end

  def self.down
    remove_column :tokens, :updated_on
  end
end
