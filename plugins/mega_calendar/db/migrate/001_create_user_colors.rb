class CreateUserColors < ActiveRecord::Migration[ActiveRecord::VERSION::MAJOR.to_s + '.' + ActiveRecord::VERSION::MINOR.to_s]
  def up
    create_table :user_colors do |t|
      t.string :color_code
      t.integer :user_id
    end
  end
  def down
    drop_table(:user_colors)
  end
end
