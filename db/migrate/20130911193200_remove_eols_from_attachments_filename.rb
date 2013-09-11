class RemoveEolsFromAttachmentsFilename < ActiveRecord::Migration
  def up
    Attachment.where("filename like ? or filename like ?", "%\r%", "%\n%").each do |attachment|
      filename = attachment.filename.to_s.tr("\r\n", "_")
      Attachment.where(:id => attachment.id).update_all(:filename => filename)
    end
  end

  def down
    # nop
  end
end
