class CreateGithubUsers < ActiveRecord::Migration
  def change
    create_table :github_users do |t|
      t.column :login, :string
      t.references :user
    end
  end
end
