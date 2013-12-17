class CreateGithubProjects < ActiveRecord::Migration
  def change
    create_table :github_projects do |t|
      t.column :organization, :string
      t.column :project_name, :string
      t.references :project
    end
  end
end