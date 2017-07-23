class ChangeProjectsDescriptionToText < ActiveRecord::Migration[4.2]
  def self.up
    change_column :projects, :description, :text, :null => true, :default => nil
  end

  def self.down
  end
end
