class CreateMailSourceBlacklist < ActiveRecord::Migration[6.1]
  def change
    create_table :mail_source_blacklists do |t|
      t.string :email, null: false, index: true
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
