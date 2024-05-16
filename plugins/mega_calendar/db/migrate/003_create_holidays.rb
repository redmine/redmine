class CreateHolidays < ActiveRecord::Migration[ActiveRecord::VERSION::MAJOR.to_s + '.' + ActiveRecord::VERSION::MINOR.to_s]
  def up
    create_table :holidays do |t|
      t.datetime :start
      t.datetime :end
      t.integer :user_id
    end
  end
  def down
    drop_table(:holidays)
  end
end
