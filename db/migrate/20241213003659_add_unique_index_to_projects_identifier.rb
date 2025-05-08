class AddUniqueIndexToProjectsIdentifier < ActiveRecord::Migration[7.2]
  def change
    add_index :projects, :identifier, :unique => true
  end
end
