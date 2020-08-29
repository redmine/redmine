class AddTwofaSchemeToUser < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :twofa_scheme, :string
  end
end
