require 'business_time'
class MailTrackingRule < ActiveRecord::Base
  unloadable

  has_many :issues_mail_tracking_rules
  def self.build_attachments_from_mail mail, issue
    mail.attachments.to_a.map do |attachment|
      # validate if attachment is bigger than 1000 bytes
      file = DataStringIO.new(attachment.filename, attachment.mime_type, attachment.body.decoded)
      if file.size > 10.kilobytes && file.size < Setting.attachment_max_size.to_i.kilobytes && ((attachment.content_type.start_with?('image/')) || (attachment.content_type.start_with?('audio/')))
        content_id = attachment.content_id.tr('<>', '') if attachment.inline? && attachment.content_id.present?
        doc = Attachment.new(
          file: DataStringIO.new(attachment.filename, attachment.mime_type, attachment.body.decoded),
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

  def self.apply_rules(mail,no_rules_project_id,default_user,desc,source_email)
    # TODO: Make a single request instead of eaching everything
    found_rule = nil
    self.all.order(:created_at).each do |rule|
      case rule.mail_part
      when 'From'
        if mail.from.first.present? && (mail.from.first.upcase.include? rule.includes.upcase)
          found_rule = rule
        end
      when 'CC'
        if mail.cc.present? && (mail.cc.upcase.include? rule.includes.upcase)
          found_rule = rule
        end
      when 'Subject'
        if mail.subject.present? && (mail.subject.upcase.include? rule.includes.upcase)
          found_rule = rule
        end
      when 'Body'
        if desc.to_s.gsub("\u0000", '').upcase.include? rule.includes.upcase
          found_rule = rule
        end
      end
      break if found_rule
    end

    # found_rule = nil
    # [:from, :cc, :subject, :body].each do |mail_part|
    #   if mail.send(mail_part).try(:present?)
    #     found_rule = MailTrackingRule.where(mail_part: mail_part)
    #                                  .where("includes like ?", "%#{mail.send(mail_part).try(:first)}%")
    #                                  .try(:first)
    #     break if found_rule
    #   end
    # end
    
    dup_issue = if mail.in_reply_to.present?
                  if mail.in_reply_to.to_s[%r{^<?redmine\.([a-z0-9_]+)\-(\d+)\.\d+(\.[a-f0-9]+)?@}]
                    if $1.to_s == 'journal'
                      Journal.find_by(id: $2.to_i).issue if Journal.exists?(id: $2.to_i)
                    end
                  else
                    Issue.find_by(reply_message_id: mail.in_reply_to)
                  end
                end
    
    if dup_issue.present?# && !dup_issue.closed?

      a = Nokogiri::HTML(desc.to_s.gsub("\u0000", ''))
      if a.present?
        a.xpath('//div[contains(@class, "15329827815651384WordSection1")]').each do |item|
            item.remove
        end
        a.search("div").each do |item|
          item.try(:replace, item.try(:content))
        end
        note = a.text
      end
      
      note = desc.to_s.gsub("\u0000", '') if note.blank?
      cut_items_list = MailSource.mails_source_first_or_new.reply_cut_from&.split("\n") || []
      cut_items_list.each do |cut_item|
        original_message_index = note.index(cut_item.strip) || 0
        note = note[0..original_message_index - 1] if original_message_index.positive?
      end

      # user_id: found_rule&.login_name || dup_issue.author_id
      journal = Journal.new({
        notes: note,
        journalized_id: dup_issue.id,
        journalized_type: "Issue",
        user_id: User.having_mail(mail.try(:from).try(:presence)).try(:first).try(:id) || dup_issue.author_id
      })
      journal.save
      dup_issue.update_column(:reply_message_id, mail.message_id)
      MailTrackingRule.build_attachments_from_mail(mail, dup_issue)

    elsif mail.subject.present?
      # check if mail is sent as cc
      MailTrackerCustomLogger.logger.info("Mail TO: #{mail.to}, Mail CC: #{mail.cc}, Source Emal: #{source_email}")
      unless mail.cc.present? && source_email.present? && mail.cc.join(',').upcase.include?(source_email.upcase) && (mail.to.present? && !mail.to.join(',').upcase.include?(source_email.upcase))
        new_status = IssueStatus.find_by(name:"New")
        new_status_id = new_status.present? ? new_status.id : 1
        default_tracker = Tracker.find_by(name: "Support")
        default_tracker_id = default_tracker.present? ? default_tracker.id : 1
        if found_rule.present?

          if found_rule.priority.present? && found_rule.end_duration.present?
            t = found_rule.end_duration.seconds
            mm, ss = t.divmod(60)
            hh, mm = mm.divmod(60)
            case found_rule.priority
            when 'Low'
              due_date = hh.business_hours.after(Time.now + mm.minutes)
            when 'Medium'
              BusinessTime::Config.work_week = [:mon, :tue, :wed, :thu, :fri, :sat, :sun]
              due_date = hh.business_hours.after(Time.now + mm)
              BusinessTime::Config.work_week = [:mon, :tue, :wed, :thu, :fri]
            when 'High'
              due_date = (Time.now + hh.hours + mm.minutes)
            end
          end

          ch_user = found_rule.login_name.present? ? found_rule.login_name : default_user
          issue = {
            "subject": mail.subject,
            "tracker_id": found_rule.tracker_name,
            "project_id": found_rule.assigned_project_id,
            "author_id": ch_user,
            "status_id": new_status_id,
            "is_private": false,
            "description": desc.to_s.gsub("\u0000", ''),
            "assigned_to_id": found_rule.assigned_group_id,
            "message_id": mail.message_id,
            "start_date": Time.now,
            "due_date": due_date,
          }
        else
          issue = {
            "subject": mail.subject,
            "tracker_id": default_tracker_id,
            "project_id": no_rules_project_id,
            "author_id": default_user,
            "status_id": new_status_id,
            "is_private": false,
            "description": desc.to_s.gsub("\u0000", ''),
            "message_id": mail.message_id,
            "start_date": Time.now
          }
        end
      end

    end
    { issue: issue, rule: found_rule }
  end

end