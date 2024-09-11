require 'business_time'
class MailTrackingRule < ActiveRecord::Base
  unloadable

  has_many :issues_mail_tracking_rules
  def self.build_attachments_from_mail mail, issue
    mail.attachments.to_a.map do |attachment|
      # validate if attachment is bigger than 1000 bytes
      file = DataStringIo.new(attachment.filename, attachment.mime_type, attachment.body.decoded)
      if file.size > 10.kilobytes && file.size < Setting.attachment_max_size.to_i.kilobytes && ((attachment.content_type.start_with?('image/')) || (attachment.content_type.start_with?('audio/')))
        content_id = attachment.content_id.tr('<>', '') if attachment.inline? && attachment.content_id.present?
        doc = Attachment.new(
          file: DataStringIo.new(attachment.filename, attachment.mime_type, attachment.body.decoded),
          filename: attachment.filename,
          author_id: issue.author_id,
          container_type: "Issue",
          container_id: issue.id,
          mail_content_id: content_id
        )
        doc.save
      end
    end
  end

  # def self.apply_rules(email, no_rules_project_id, default_user, content, source_email)
  def self.apply_rules(email, content)
    MailTrackingRule.where(
      "mail_part = 'From' AND includes ILIKE ?", "%#{email.from.first}%"
    ).or(
      MailTrackingRule.where(
        "mail_part = 'CC' AND includes ILIKE ?", "%#{email.cc}%"
      )
    ).or(
      MailTrackingRule.where(
        "mail_part = 'Subject' AND includes ILIKE ?", "%#{email.subject}%"
      )
    ).or(
      MailTrackingRule.where(
        "mail_part = 'Body' AND includes ILIKE ?", "%#{content.to_s.gsub("\u0000", '')}%"
      )
    ).group(:id).order(created_at: :asc).first
  end
end