class RemoveOrphanedCustomValueAttachments < ActiveRecord::Migration[7.2]
  def up
    Attachment.where(container_type: 'CustomValue')
              .where('NOT EXISTS (SELECT 1 FROM custom_values WHERE custom_values.id = attachments.container_id)')
              .destroy_all
  end

  def down
    # no-op
  end
end
