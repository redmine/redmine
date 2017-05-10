class RemoveEnumerationsOpt < ActiveRecord::Migration
  def self.up
    remove_column :enumerations, :opt
  end

  def self.down
    add_column :enumerations, :opt, :string, :limit => 4, :default => '', :null => false
    Enumeration.where("type = 'IssuePriority'").update_all("opt = 'IPRI'")
    Enumeration.where("type = 'DocumentCategory'").update_all("opt = 'DCAT'")
    Enumeration.where("type = 'TimeEntryActivity'").update_all("opt = 'ACTI'")
  end
end
