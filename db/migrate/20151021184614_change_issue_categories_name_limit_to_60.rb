class ChangeIssueCategoriesNameLimitTo60 < ActiveRecord::Migration
  def self.up 
    change_column :issue_categories, :name, :string, :limit => 60, :default => "", :null => false
  end

  def self.down
    change_column :issue_categories, :name, :string, :limit => 30, :default => "", :null => false
  end
end
