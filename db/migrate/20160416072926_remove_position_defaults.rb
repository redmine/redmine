class RemovePositionDefaults < ActiveRecord::Migration
  def up
    [Board, CustomField, Enumeration, IssueStatus, Role, Tracker].each do |klass|
      change_column klass.table_name, :position, :integer, :default => nil
    end
  end

  def down
    [Board, CustomField, Enumeration, IssueStatus, Role, Tracker].each do |klass|
      change_column klass.table_name, :position, :integer, :default => 1
    end
  end
end
