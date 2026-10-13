class CreateNonWorkingDates < ActiveRecord::Migration[8.1]
  def change
    create_table :non_working_dates do |t|
      t.date :date, :null => false
      t.string :name
    end
    add_index :non_working_dates, :date, :unique => true
  end
end
