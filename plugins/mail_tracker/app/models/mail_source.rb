require 'openssl'
require 'httparty'

class MailSource < ActiveRecord::Base
  include ActionView::Helpers
  include Rails.application.routes.url_helpers
  include Redmine::I18n
  ENCODING = 'UTF-8'.freeze
  BIN_ENCODING = 'ASCII-8BIT'.freeze
  ATTACHMENT_EXTENSIONS = %w[xls xlsx doc docx ods pdf].freeze
  INVALID_CHARACTERS = [
    160,
    158,
    194
  ].map(&:chr)
  DEFAULT_PROTOCOL = 'pop3'.freeze
  DEFAULT_EMAIL_SUBJECT = 'Jūsų užduotis užregistruota redmine sistemoje'.freeze
  REDIRECT_URI = 'https://crm.softra.lt/oauth/callback'

  # def initialize
  #   @email = self.first.username
  #   @password = self.first.password
  #   @server = self.first.host
  #   @ssl = true
  # end

  def permission_request
    "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?nonce=mailtracer&client_id=#{application_id}&response_type=code%20id_token&redirect_uri=#{REDIRECT_URI}&response_mode=form_post&scope=openid%20offline_access%20https%3A%2F%2Foutlook.office365.com%2FIMAP.AccessAsUser.All%20https%3A%2F%2Foutlook.office365.com%2FSMTP.Send%20https%3A%2F%2Foutlook.office365.com%2Femail&state=redminemail"
  end

  def access_request
    "https://login.microsoftonline.com/common/oauth2/v2.0/token?client_id=#{application_id}&code=#{azure_code}&grant_type=authorization_code&client_secret=#{password}&redirect_uri=#{REDIRECT_URI}&scope=openid%20offline_access%20https%3A%2F%2Foutlook.office365.com%2FIMAP.AccessAsUser.All%20https%3A%2F%2Foutlook.office365.com%2FSMTP.Send%20https%3A%2F%2Foutlook.office365.com%2Femail"
  end

  def is_active?
    `cd plugins/mail_tracker && crontab -l`.blank? ? false : true
  end

  def default_opts
    oauth_enabled ? oauth2_opts : basic_opts
  end

  def basic_opts
    {
      address: receive_host,
      user_name: username,
      enable_ssl: use_ssl,
      password: password
    }
  end

  def oauth2_opts
    {
      address: receive_host,
      user_name: email_address,
      enable_ssl: use_ssl,
      password: access_token,
      authentication: 'XOAUTH2'
    }
  end

  def imap_options
    default_opts.merge(port: use_ssl ? (receive_port || 993) : (receive_port || 143))
  end

  def pop3_options
    default_opts.merge(port: use_ssl ? (receive_port || 995) : (receive_port || 110))
  end

  def try_connection
    parse(receive_protocol) { yield }
  rescue StandardError => e
    raise e, "Connection to #{host} failed."
  end

  def parse(protocol)
    token_refresher if oauth_enabled && refresh_token
    token_receiver if oauth_enabled && refresh_token.nil?
    options = send("#{protocol}_options")
    Mail.defaults do
      retriever_method protocol.to_sym, options
    end

    yield
  end

  def token_receiver
    body = {
      client_id: application_id,
      scope: 'openid offline_access',
      code: azure_code,
      redirect_uri: REDIRECT_URI,
      grant_type: 'authorization_code',
      client_secret: password
    }
    request = HTTParty.post("https://login.microsoftonline.com/common/oauth2/v2.0/token", body: body)
    request = JSON.parse(request.body)
    update!(
      access_token: request['access_token'],
      refresh_token: request['refresh_token'],
      id_token: request['id_token']
    )
    reload
  end

  def token_refresher
    body = {
      client_id: application_id,
      scope: 'openid offline_access',
      refresh_token: refresh_token,
      grant_type: 'refresh_token',
      client_secret: password
    }
    request = HTTParty.post("https://login.microsoftonline.com/common/oauth2/v2.0/token", body: body)
    request = JSON.parse(request.body)
    update!(
      access_token: request['access_token'],
      refresh_token: request['refresh_token']
    )
    reload
  end

  def domain
    email_address.split('@').last
  end

  def delivery_options
    options = {
      enable_starttls_auto: use_tls,
      address: host,
      port: delivery_port || 587,
      domain: domain,
      openssl_verify_mode: 'none'
    }
    extras = oauth_enabled ?
      { authentication: 'XOAUTH2', user_name: email_address, password: access_token } :
      { authentication: :login, user_name: username, password: password }
    options.merge(extras)
  end

  def deliver(mail)
    mail.delivery_method :smtp, delivery_options

    MailTrackerCustomLogger.logger.info("Using SMTP #{host}, PORT: #{delivery_port}, DOMAIN:#{domain}, USERNAME: #{username}")
    MailTrackerCustomLogger.logger.info("Delivering from #{mail.from} to #{mail.to}: #{mail.subject}")

    begin
      mail.deliver!
    rescue StandardError => e
      MailTrackerCustomLogger.logger.info("Delivering error - #{e}")
      raise e
    end
  end

  def last(count = 10)
    try_connection do
      Mail.find(what: :last, count: count, order: :dsc, read_only: true)
    end
  end

  def find(id)
    try_connection do
      Mail.find(what: :first, keys: ['HEADER', 'MESSAGE-ID', id], read_only: true).first
    end
  end

  def unseen
    try_connection do
      Mail.find(what: :all, keys: %w[NOT SEEN], read_only: true)
    end
  end

  def mark_as_seen(id)
    try_connection do
      Mail.find(what: :first, keys: ['HEADER', 'MESSAGE-ID', id]).first
    end
  end

  def get_issue_path(issue)
    domain = if Rails.env.development?
               'http://localhost:3000'
             else
               #  parsed_url = URI.parse(issue.project.host_name)

               #  !parsed_url.scheme ? "https://#{issue.project.host_name}" : issue.project.host_name

               "https://#{issue.project.crm_host_name}"
             end

    domain + issue_path(issue)
  end

  def build_attachments_from_mail(mail, issue)
    docs = []
    mail.attachments.to_a.map do |attachment|
      # validate if attachment is bigger than 1000 bytes
      file = DataStringIO.new(attachment.filename, attachment.mime_type, attachment.body.decoded)
      unless file.size > 10.kilobytes && file.size < Setting.attachment_max_size.to_i.kilobytes && (attachment.content_type.start_with?('image/') || attachment.content_type.start_with?('audio/'))
        next
      end

      content_id = attachment.content_id.tr('<>', '') if attachment.inline? && attachment.content_id.present?
      doc = Attachment.new(
        file: DataStringIO.new(attachment.filename, attachment.mime_type, attachment.body.decoded),
        filename: attachment.filename,
        author_id: issue.author_id,
        container_type: 'Issue',
        container_id: issue.id,
        mail_content_id: content_id
      )
      docs << doc if doc.save
    end
    issue.attachments = docs if docs.present?
  end

  def create_from_mail(mail)
    remove_from_to = '<Undisclosed recipients:>'

    content_part = mail.html_part.presence || mail.text_part.presence || mail
    _content = get_content_body(content_part.body)
    if (_content || mail.attachments.any?) && mail.date.present?
      _content = Nokogiri::HTML(_content, nil, content_part.charset).at('body')
      _content = _content.inner_html.encode(ENCODING, invalid: :replace, undef: :replace, replace: '') if _content
      retried = false
      begin
        avilable_domains = ProjectEmail.all_uniq_domains
        email = begin
          mail.to.find do |mail_address|
            avilable_domains.include?(Mail::Address.new(mail_address).domain)
          end
        rescue StandardError
          mail.to.to_s.gsub(remove_from_to, '')
        end

        email = Mail::Address.new(email)

        support_emails = avilable_domains.map { |item| "support@#{item}" }
        support_cc_email = begin
          mail.cc.find do |mail_address|
            support_emails.include?(mail_address)
          end
        rescue StandardError
          nil
        end
        support_cc_email ||= 'support@softra.lt'
        generated_issues_mail_tracking_rules = MailTrackingRule.apply_rules(mail, no_rules_project_id, default_user_id,
                                                                            _content, support_cc_email)

        if generated_issues_mail_tracking_rules[:issue].present?
          tstart = generated_issues_mail_tracking_rules[:issue][:start_date]
          tend = generated_issues_mail_tracking_rules[:issue][:due_date]
        end

        # Are we really supposed to INITIALIZE NEW ISSUE?
        # Why don't we just FIND or INITIALIZE?
        issue = Issue.new(generated_issues_mail_tracking_rules[:issue])
        if issue.save
          if generated_issues_mail_tracking_rules[:rule].present?
            IssuesMailTrackingRule.create(mail_tracking_rule_id: generated_issues_mail_tracking_rules[:rule].id,
                                          issue_id: issue.id)
          end
          if (tstart.present? && tend.present?) || tstart.present? || tend.present?
            begin
              TicketTime.create({ issue_id: issue.id, time_begin: tstart, time_end: tend })
            rescue StandardError
              nil
            end
          end
          watchers = []
          # find all users from group support, and then add as watchers by default to all issues created from mails
          if issue.project.watcher_groups.present?
            watcher_groups = issue.project.watcher_groups
            watcher_users = watcher_groups.map(&:user_ids).flatten
            watchers += watcher_users.uniq if watcher_users.present?
          elsif issue.assigned_to_id.present?
            group = Group.find(issue.assigned_to_id)
            group_users = group.users.pluck(:id) if group.present?
            watchers += group_users if group_users.present?
          else
            support_group = Group.find_by(lastname: 'Support')
            support_users = support_group.users.pluck(:id) if support_group.present?
            watchers += support_users if support_users.present?
          end

          if mail.cc.present?
            addresses = EmailAddress.all if EmailAddress.all.count > 0
            mail_cc = mail.cc
            intersection = addresses.pluck(:address) & mail_cc if addresses.present?
            out = EmailAddress.where(address: intersection) if intersection.present?
            cc_users = out.pluck(:user_id) if out.present?
            watchers += cc_users if cc_users.present?
          end

          if mail.cc.present?
            emails = []
            emails += mail.from
            emails += mail.cc
            group_ids = Group.where(group_email: emails).map(&:user_ids).flatten
            watchers += group_ids if group_ids.present?
          else
            group_ids = Group.find_by(group_email: mail.from).try(:user_ids)
            watchers += group_ids if group_ids.present?
          end

          # watchers << issue.assigned_to_id if issue.assigned_to_id.present?
          watchers << issue.author_id if issue.author_id.present?

          watchers.uniq!
          watchers.each do |e|
            w = Watcher.new(watchable_type: 'Issue', watchable_id: issue.id, user_id: e)
            w.save
          end
          build_attachments_from_mail(mail, issue)
          link = get_issue_path(issue)
          user = User.find(issue.author_id).try(:login)
          user = 'mail_no_username' if issue.author_id == default_user_id || user.blank?
          replaced_body_keywords = EmailTemplate.template_by_domain(domain: email.domain).converted_body(link, user)
          temp_mail = Mail.new do
            from      issue.project.email
            to        mail.from
            in_reply_to mail.message_id
            references  mail.message_id
            subject(mail.subject ? "RE: #{mail.subject}" : DEFAULT_EMAIL_SUBJECT)
            html_part do
              content_type 'text/html; charset=UTF-8'
              body ApplicationController.helpers.textilizable(replaced_body_keywords)
            end
          end
          unless mail.from.present? && %w[support-ru support-en support-lt admin-ru admin-en
                                          admin-lt].include?(Mail::Address.new([mail.from].flatten.first).local)
            deliver(temp_mail)
            issue.update_column(:reply_message_id, temp_mail.message_id)
          end
          mark_as_seen(mail.message_id) if mail.message_id.present?
          p "Issue registred with: #{issue.id}. Message id: #{mail.message_id}"
          p '---------------------------'
        else
          # if mail is already created, mark as seen
          mark_as_seen(mail.message_id) if mail.message_id.present?
          p "Issue was not generated. These are errors: #{issue.errors.messages}"
          p '---------------------------'
        end
      rescue ActiveRecord::StatementInvalid => e
        raise e if retried

        _content = handle_invalid_encoding(_content, content_part.charset)
        retried = true
        retry
      rescue StandardError => e
        MailTrackerCustomLogger.logger.error(e)
        raise e
      end
    else
      mark_as_seen(mail.message_id) if mail.message_id.present?
      p "Issue was blank and message id is: #{mail.message_id}"
      p '---------------------------'
    end
  end

  def fetch_mails
    mails = unseen
    mails.each do |mail|
      create_from_mail(mail)
    end
  end

  def self.check_issues_validity
    # TODO: move to settings panel?
    project_to_sync = mails_source_first_or_new.projects_to_sync.present? ? (JSON.parse mails_source_first_or_new.projects_to_sync.to_s) : []
    issues = project_to_sync.present? ? Issue.where(id: project_to_sync).where(closed_on: nil) : []

    issues.each do |issue|
      has_changed_to_approved = nil
      record_found = nil
      issue.journals.where(user_id: issue.author_id).order(created_on: :desc).each do |record|
        details = record.visible_details
        record_found = details.select { |i| i.prop_key == 'status_id' }.first if details.present?
        has_changed_to_approved = (record_found.value == '15') if record_found.present?
        break if record_found.present?
      end
      next unless record_found.present? && has_changed_to_approved

      closedStatus = IssueStatus.find_by(name: 'Closed')
      issue.closed_on = Time.current
      issue.status = closedStatus
      if issue.save!
        puts "IssuesByClientApproved issue with id #{issue.id} in project #{issue.project.present? ? issue.project.name : 'unknown'} has been closed"
      end
      puts '-----------------------------'
    end

    issues.each do |issue|
      record = issue.journals.order(created_on: :desc).first
      next unless record.present? && (record.user_id != issue.author_id) && (record.created_on + 3.days < Time.current)

      closedStatus = IssueStatus.find_by(name: 'Closed')
      issue.closed_on = Time.current
      issue.status = closedStatus
      if issue.save!
        puts "IssuesByNoCommentOver3Days issue with id #{issue.id} in project #{issue.project.present? ? issue.project.name : 'unknown'}  has been closed"
      end
      puts '-----------------------------'
    end
  end

  def self.mails_source_first_or_new
    MailSource.first || MailSource.create
  end

  def self.each_mail_source_fetch_mails
    MailSource.where(enabled_sync: true).each do |mail_source|
      mail_source.fetch_mails
    end
  end

  def handle_invalid_encoding(content, charset)
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

  def get_content_body(mail_body)
    mail_body.presence && mail_body.decoded.presence
  rescue Mail::UnknownEncodingType
    mail_body.encoded.presence
  end

  def receivers=(_receivers)
    super _receivers.is_a?(Array) ? _receivers : _receivers.to_s.split(/,|;/).map(&:strip)
  end
  # def fetch_mails
  #   # File.open('cron.test', 'w') { |f| f.write('Hello') }
  #   puts "test"
  # end

  def project
    Project.find(default_project_id) if default_project_id.present?
  end
end