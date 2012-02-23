class ChangeAttachmentsContainerDefaults < ActiveRecord::Migration
  def self.up
    change_column :attachments, :container_id, :integer, :default => nil, :null => true
    change_column :attachments, :container_type, :string, :limit => 30, :default => nil, :null => true
    Attachment.update_all "container_id = NULL", "container_id = 0"
    Attachment.update_all "container_type = NULL", "container_type = ''"
  end

  def self.down
    change_column :attachments, :container_id, :integer, :default => 0, :null => false
    change_column :attachments, :container_type, :string, :limit => 30, :default => "", :null => false
  end
end
