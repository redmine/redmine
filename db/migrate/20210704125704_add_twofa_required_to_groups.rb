class AddTwofaRequiredToGroups < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :twofa_required, :boolean, default: false
  end
end
