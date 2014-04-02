class ChangeAttachmentsContainerDefaults < ActiveRecord::Migration
  def self.up
    # Need to drop the index otherwise the following error occurs in Rails 3.1.3:
    #
    # Index name 'temp_index_altered_attachments_on_container_id_and_container_type' on
    # table 'altered_attachments' is too long; the limit is 64 characters
    remove_index :attachments, [:container_id, :container_type]

    change_column :attachments, :container_id, :integer, :default => nil, :null => true
    change_column :attachments, :container_type, :string, :limit => 30, :default => nil, :null => true
    Attachment.where("container_id = 0").update_all("container_id = NULL")
    Attachment.where("container_type = ''").update_all("container_type = NULL")

    add_index :attachments, [:container_id, :container_type]
  end

  def self.down
    remove_index :attachments, [:container_id, :container_type]

    change_column :attachments, :container_id, :integer, :default => 0, :null => false
    change_column :attachments, :container_type, :string, :limit => 30, :default => "", :null => false

    add_index :attachments, [:container_id, :container_type]
  end
end
