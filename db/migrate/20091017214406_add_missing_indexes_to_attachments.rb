class AddMissingIndexesToAttachments < ActiveRecord::Migration[4.2]
  def self.up
    add_index :attachments, [:container_id, :container_type]
    add_index :attachments, :author_id
  end

  def self.down
    remove_index :attachments, :column => [:container_id, :container_type]
    remove_index :attachments, :author_id
  end
end
