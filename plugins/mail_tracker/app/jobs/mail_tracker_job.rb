# frozen_string_literal: true

class MailTrackerJob < ApplicationJob
  include Rails.application.routes.url_helpers
  include Redmine::I18n
  
  ENCODING = 'UTF-8'.freeze
  BIN_ENCODING = 'ASCII-8BIT'.freeze
  DEFAULT_EMAIL_SUBJECT = 'Jūsų užduotis užregistruota redmine sistemoje'.freeze
  INVALID_CHARACTERS = [
    160,
    158,
    194
  ].map(&:chr)
  REMOVE_FROM_TO = '<Undisclosed recipients:>'.freeze

  def perform(mail_source_id)
    @mail_source = MailSource.find_by(id: mail_source_id)
    @mail_source&.unseen&.each do |email|
      log_string = "*****\nMessage id: #{email.message_id}, From: #{email.from}, To: #{email.to}, Subject: #{email.subject}, Date: #{email.date}"
      MailTrackerCustomLogger.logger.info(log_string)
      create_issue_from_email(email)
    end
  end

  private

  def create_issue_from_email(email)
    content_part = email.html_part.presence || email.text_part.presence || email
    email_body = get_content_body(content_part.body)

    parse_email(email, content_part, email_body) if (email_body || email.attachments.any?) && email.date.present?
  end

  def parse_email(email, content_part, email_body)
    content = Nokogiri::HTML(email_body, nil, content_part.charset).at('body')
    content = content.inner_html.encode(ENCODING, invalid: :replace, undef: :replace, replace: '') if content
    retried = false

    begin
      mail_tracking_rule(email, content)
      issue_duplicate(email)

      if @issue.present?
        assign_journal(email, content)
      else
        assign_issue(email, content)
      end

      @mail_source.mark_as_seen(email.message_id)
    rescue ActiveRecord::RecordInvalid => e
      if e.to_s.include?('Message has already been taken')
        log_string = "Taken message id: #{email.message_id}, From: #{email.from}, To: #{email.to}, Subject: #{email.subject}, Date: #{email.date}, Issue params: #{@issue_params}, Trace: #{e.backtrace}"
        MailTrackerCustomLogger.logger.error(log_string)
        @mail_source.mark_as_seen(email.message_id)
      else
        Sentry.capture_exception(e)
        log_string = "Error message id: #{email.message_id}, From: #{email.from}, To: #{email.to}, Subject: #{email.subject}, Date: #{email.date}, Issue params: #{@issue_params}, Error: #{e}, Trace: #{e.backtrace}"
        MailTrackerCustomLogger.logger.error(log_string)
      end
    rescue => e
      Sentry.capture_exception(e)
      log_string = "General error message id: #{email.message_id}, From: #{email.from}, To: #{email.to}, Subject: #{email.subject}, Date: #{email.date}, Issue params: #{@issue_params}, Error: #{e}, Trace: #{e.backtrace}"
      MailTrackerCustomLogger.logger.error(log_string)
    ensure
      log_string = "***\nMessage id: #{email.message_id}, From: #{email.from}, To: #{email.to}, Subject: #{email.subject}, Date: #{email.date}, Issue params: #{@issue_params}"
      MailTrackerCustomLogger.logger.info(log_string)
      @issue = nil
      @issue_params = nil
      @mail_tracking_rule = nil
      @due_date = nil
      @to = nil
      @support_cc_email = nil
    end
  end

  def notify_sender(email)
    link = issue_url(@issue, host: Setting.host_name)
    user = User.find(@issue.author_id).try(:login)
    user = 'mail_no_username' if @issue.author_id == @mail_source.default_user_id || user.blank?

    # Remove undisclosured recipients
    avilable_domains = ProjectEmail.all_uniq_domains
    email.to = begin
      email.to.find do |mail_address|
        avilable_domains.include?(Mail::Address.new(mail_address).domain)
      end
    rescue StandardError
      email.to.to_s.gsub(REMOVE_FROM_TO, '')
    end
    replaced_body_keywords = EmailTemplate.template_by_domain(domain: Mail::Address.new([email.to].flatten.first).domain).converted_body(link, user)
    
    temp_mail = Mail.new
    temp_mail.from = @issue.project.email
    temp_mail.to = email.from
    temp_mail.in_reply_to = email.message_id
    temp_mail.references = email.message_id
    temp_mail.subject = email.subject ? "RE: #{email.subject}" : DEFAULT_EMAIL_SUBJECT
    temp_mail.html_part = Mail::Part.new
    temp_mail.html_part.content_type = 'text/html; charset=UTF-8'
    temp_mail.html_part.body = ApplicationController.helpers.textilizable(replaced_body_keywords)

    unless email.from.present? && %w[support-ru support-en support-lt admin-ru admin-en
                                    admin-lt].include?(Mail::Address.new([email.from].flatten.first).local)
      @mail_source.deliver(temp_mail)
      @issue.update!(reply_message_id: temp_mail.message_id)
    end
  end

  def handle_invalid_encoding(content, charset)
    return content if content.blank?

    encoded = content.dup.force_encoding(BIN_ENCODING)

    if INVALID_CHARACTERS.any?(&encoded.method(:include?)) && content.encoding.to_s == ENCODING
      binary_encoded = content.force_encoding(BIN_ENCODING)

      INVALID_CHARACTERS.each do |char|
        binary_encoded.gsub!(char, '')
      end

      binary_encoded.force_encoding(ENCODING)
    else
      content.force_encoding(charset.upcase.eql?(ENCODING) ? 'ISO-8859-13' : charset).encode(ENCODING)
    end
  end

  def assign_issue(email, content)
    MailTrackerCustomLogger.logger.info("Assign issue: #{[email.cc.present?, support_email.present?, email&.cc&.join(',')&.upcase&.include?(support_email.upcase), (email.to.present? && !email.to&.join(',')&.upcase&.include?(support_email&.upcase))]}")
    return if email.cc.present? && support_email.present? && email&.cc&.join(',')&.upcase&.include?(support_email.upcase) && (email.to.present? && !email.to&.join(',')&.upcase&.include?(support_email.upcase))

    issue_params(email, content)
    @issue = Issue.new(@issue_params)
    if @issue.save!
      MailTrackerCustomLogger.logger.info("Issue created. Details: #{@issue.inspect}")
      upload_attachments(email)
      assign_watchers(email)
      notify_sender(email)
    else
      raise StandardError, "Issue not saved: #{@issue_params}, Errors: #{@issue&.errors}, Trace: #{@issue&errors&full_messages}"
    end
  end

  def assign_journal(email, content)
    note = cut_reply_text(content)
    journal = Journal.new({
      notes: note,
      journalized_id: @issue.id,
      journalized_type: "Issue",
      user_id: User.having_mail(email.try(:from).try(:presence)).try(:first).try(:id) || @issue.author_id
      })
    journal.save!
    @issue.update!(reply_message_id: email.message_id)
    upload_attachments(email)
    MailTrackerCustomLogger.logger.info("Journal created. Details: #{journal.inspect}")
  end

  def assign_watchers(email)
    # Initialize an empty array for watchers
    watchers = []

    # Add watchers from project watcher groups
    if @issue.project.watcher_groups.present?
      watcher_users = @issue.project.watcher_groups.flat_map(&:user_ids).uniq
      watchers.concat(watcher_users) if watcher_users.present?

    # Add watchers from assigned group
    elsif @issue.assigned_to_id.present?
      group_users = Group.find(@issue.assigned_to_id)&.users&.pluck(:id)
      watchers.concat(group_users) if group_users.present?

    # Add watchers from the support group
    else
      support_group_users = Group.find_by(lastname: 'Support')&.users&.pluck(:id)
      watchers.concat(support_group_users) if support_group_users.present?
    end

    # Add watchers from email CC
    if email.cc.present?
      email_addresses = EmailAddress.pluck(:address, :user_id).to_h
      mail_cc_addresses = email.cc
      cc_user_ids = email_addresses.slice(*mail_cc_addresses).values
      watchers.concat(cc_user_ids) if cc_user_ids.present?
    end

    # Add watchers from group emails
    emails = email.from + (email.cc || [])
    group_user_ids = Group.where(group_email: emails).flat_map(&:user_ids)
    watchers.concat(group_user_ids) if group_user_ids.present?

    # Add the issue author as a watcher
    watchers << @issue.author_id if @issue.author_id.present?

    # Ensure watcher user IDs are unique
    watchers.uniq!

    # Save each watcher
    watchers.each do |user_id|
      Watcher.create(watchable_type: 'Issue', watchable_id: @issue.id, user_id: user_id)
    end
  end

  def issue_params(email, content)
    @issue_params = {
      "subject": email.subject,
      "tracker_id": @mail_tracking_rule&.tracker_name&.presence || @mail_source.default_tracker_id,
      "project_id": @mail_tracking_rule&.assigned_project_id&.presence || @mail_source.no_rules_project_id,
      "author_id": @mail_tracking_rule&.login_name&.presence || @mail_source.default_user_id,
      "status_id": IssueStatus.find_by(name: 'New')&.id&.presence || 1,
      "is_private": false,
      "description": content&.to_s&.gsub("\u0000", ''),
      "message_id": email.message_id,
      "start_date": Time.now,
      "due_date": @due_date,
      "assigned_to_id": @mail_tracking_rule&.assigned_group_id&.presence,
    }

    @issue_params.merge!({
      "issues_mail_tracking_rules_attributes": {
        "0": {
          "mail_tracking_rule_id": @mail_tracking_rule&.id
        }
      }
    }) if @mail_tracking_rule&.id.present?
  end

  def mail_tracking_rule(email, content)
    @mail_tracking_rule ||= MailTrackingRule.apply_rules(email, content)
    due_date(@mail_tracking_rule) if @mail_tracking_rule.present?
  end

  def due_date(mail_tracking_rule)
    t = mail_tracking_rule.end_duration.seconds
    mm, ss = t.divmod(60)
    hh, mm = mm.divmod(60)
    @due_date ||= case mail_tracking_rule.priority
                  when 'Low'
                    hh.business_hours.after(Time.now + mm.minutes)
                  when 'Medium'
                    BusinessTime::Config.work_week = [:mon, :tue, :wed, :thu, :fri, :sat, :sun]
                    hh.business_hours.after(Time.now + mm)
                    BusinessTime::Config.work_week = [:mon, :tue, :wed, :thu, :fri]
                  when 'High'
                    (Time.now + hh.hours + mm.minutes)
                  else
                    nil
                  end
  end

  def upload_attachments(email)
    # MailTrackingRule.build_attachments_from_mail(email, @issue)
    email.attachments.to_a.map do |attachment|
      # validate if attachment is bigger than 1000 bytes
      file = DataStringIo.new(attachment.filename, attachment.mime_type, attachment.body.decoded)
      if file.size > 10.kilobytes && file.size < Setting.attachment_max_size.to_i.kilobytes && ((attachment.content_type.start_with?('image/')) || (attachment.content_type.start_with?('audio/')))
        content_id = attachment.content_id.tr('<>', '') if attachment.inline? && attachment.content_id.present?
        doc = Attachment.new(
          file: DataStringIo.new(attachment.filename, attachment.mime_type, attachment.body.decoded),
          filename: attachment.filename,
          author_id: @issue.author_id,
          container_type: "Issue",
          container_id: @issue.id,
          mail_content_id: content_id
        )
        doc.save
      end
    end
  end

  def cut_reply_text(content)
    email_text = Nokogiri::HTML(content.to_s.gsub("\u0000", ''))
    if email_text.present?
      email_text.xpath('//div[contains(@class, "15329827815651384WordSection1")]').each do |item|
        item.remove
      end
      email_text.search("div").each do |item|
        item.try(:replace, item.try(:content))
      end
      note = email_text.text
    end
    
    note = content.to_s.gsub("\u0000", '') if note.blank?
    cut_items_list = @mail_source.reply_cut_from&.split("\n") || []
    cut_items_list.each do |cut_item|
      original_message_index = note.index(cut_item.strip) || 0
      note = note[0..original_message_index - 1] if original_message_index.positive?
    end

    note
  end

  def issue_duplicate(email)
    @issue ||= if email.in_reply_to.present?
                  if email.in_reply_to.to_s[%r{^<?redmine\.([a-z0-9_]+)\-(\d+)\.\d+(\.[a-f0-9]+)?@}]
                    if $1.to_s == 'journal'
                      Journal.find_by(id: $2.to_i).issue if Journal.exists?(id: $2.to_i)
                    end
                  else
                    Issue.find_by(reply_message_id: email.in_reply_to)
                  end
                else
                  Issue.find_by(message_id: email.message_id)
                end
  end

  def to_email(email)
    @to ||= begin
      email.to.find do |mail_address|
        Mail::Address.new(available_domains.include?(Mail::Address.new(mail_address).domain))
      end
    rescue StandardError
      Mail::Address.new(email.to.to_s.gsub(@mail_source.remove_from_to, ''))
    end
  end

  def support_email
    support_emails = available_domains.map { |item| "support@#{item}" }
    @support_cc_email = begin
      mail.cc.find do |mail_address|
        support_emails.include?(mail_address)
      end
    rescue StandardError
      nil
    end
    @support_cc_email || 'support@softra.lt'
  end

  def available_domains
    ProjectEmail.all_uniq_domains
  end

  def get_content_body(mail_body)
    mail_body.presence && mail_body.decoded.presence
  rescue Mail::UnknownEncodingType
    mail_body.encoded.presence
  end
end