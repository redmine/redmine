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
    # Ensure email fields and content are sanitized and present
    from_email = email.from.first&.downcase.presence
    cc_email = email.cc.presence
    subject = email.subject.presence
    body_content = content.to_s.gsub("\u0000", '').presence
  
    # Return nil if none of the email fields or content is available
    return nil if from_email.blank? && cc_email.blank? && subject.blank? && body_content.blank?
  
    # Build the query based on which fields are present
    query = MailTrackingRule.none # Start with an empty query
  
    if from_email
      query = query.or(
        MailTrackingRule.where("mail_tracking_rules.mail_part = 'From' AND mail_tracking_rules.includes ILIKE ?", "%#{from_email}%")
      )
    end
  
    if cc_email
      query = query.or(
        MailTrackingRule.where("mail_tracking_rules.mail_part = 'CC' AND mail_tracking_rules.includes ILIKE ?", "%#{cc_email}%")
      )
    end
  
    if subject
      query = query.or(
        MailTrackingRule.where("mail_tracking_rules.mail_part = 'Subject' AND mail_tracking_rules.includes ILIKE ?", "%#{subject}%")
      )
    end
  
    if body_content
      query = query.or(
        MailTrackingRule.where("mail_tracking_rules.mail_part = 'Body' AND mail_tracking_rules.includes ILIKE ?", "%#{body_content}%")
      )
    end
  
    # Execute the query, group by ID, and order by creation time, returning the first result
    query.group(:id).order(created_at: :asc).first
  end  
end