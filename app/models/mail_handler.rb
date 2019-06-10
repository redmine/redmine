# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class MailHandler < ActionMailer::Base
  include ActionView::Helpers::SanitizeHelper
  include Redmine::I18n

  class UnauthorizedAction < StandardError; end
  class MissingInformation < StandardError; end

  attr_reader :email, :user, :handler_options

  def self.receive(raw_mail, options={})
    options = options.deep_dup

    options[:issue] ||= {}

    options[:allow_override] ||= []
    if options[:allow_override].is_a?(String)
      options[:allow_override] = options[:allow_override].split(',')
    end
    options[:allow_override].map! {|s| s.strip.downcase.gsub(/\s+/, '_')}
    # Project needs to be overridable if not specified
    options[:allow_override] << 'project' unless options[:issue].has_key?(:project)

    options[:no_account_notice] = (options[:no_account_notice].to_s == '1')
    options[:no_notification] = (options[:no_notification].to_s == '1')
    options[:no_permission_check] = (options[:no_permission_check].to_s == '1')

    raw_mail.force_encoding('ASCII-8BIT')

    ActiveSupport::Notifications.instrument("receive.action_mailer") do |payload|
      mail = Mail.new(raw_mail)
      set_payload_for_mail(payload, mail)
      new.receive(mail, options)
    end
  end

  # Receives an email and rescues any exception
  def self.safe_receive(*args)
    receive(*args)
  rescue Exception => e
    Rails.logger.error "MailHandler: an unexpected error occurred when receiving email: #{e.message}"
    return false
  end

  # Extracts MailHandler options from environment variables
  # Use when receiving emails with rake tasks
  def self.extract_options_from_env(env)
    options = {:issue => {}}
    %w(project status tracker category priority assigned_to fixed_version).each do |option|
      options[:issue][option.to_sym] = env[option] if env[option]
    end
    %w(allow_override unknown_user no_permission_check no_account_notice no_notification default_group project_from_subaddress).each do |option|
      options[option.to_sym] = env[option] if env[option]
    end
    if env['private']
      options[:issue][:is_private] = '1'
    end
    options
  end

  def logger
    Rails.logger
  end

  cattr_accessor :ignored_emails_headers
  self.ignored_emails_headers = {
    'Auto-Submitted' => /\Aauto-(replied|generated)/,
    'X-Autoreply' => 'yes'
  }

  # Processes incoming emails
  # Returns the created object (eg. an issue, a message) or false
  def receive(email, options={})
    @email = email
    @handler_options = options
    sender_email = email.from.to_a.first.to_s.strip
    # Ignore emails received from the application emission address to avoid hell cycles
    emission_address = Setting.mail_from.to_s.gsub(/(?:.*<|>.*|\(.*\))/, '').strip
    if sender_email.casecmp(emission_address) == 0
      if logger
        logger.info  "MailHandler: ignoring email from Redmine emission address [#{sender_email}]"
      end
      return false
    end
    # Ignore auto generated emails
    self.class.ignored_emails_headers.each do |key, ignored_value|
      value = email.header[key]
      if value
        value = value.to_s.downcase
        if (ignored_value.is_a?(Regexp) && value.match(ignored_value)) || value == ignored_value
          if logger
            logger.info "MailHandler: ignoring email with #{key}:#{value} header"
          end
          return false
        end
      end
    end
    @user = User.find_by_mail(sender_email) if sender_email.present?
    if @user && !@user.active?
      if logger
        logger.info  "MailHandler: ignoring email from non-active user [#{@user.login}]"
      end
      return false
    end
    if @user.nil?
      # Email was submitted by an unknown user
      case handler_options[:unknown_user]
      when 'accept'
        @user = User.anonymous
      when 'create'
        @user = create_user_from_email
        if @user
          if logger
            logger.info "MailHandler: [#{@user.login}] account created"
          end
          add_user_to_group(handler_options[:default_group])
          unless handler_options[:no_account_notice]
            ::Mailer.deliver_account_information(@user, @user.password)
          end
        else
          if logger
            logger.error "MailHandler: could not create account for [#{sender_email}]"
          end
          return false
        end
      else
        # Default behaviour, emails from unknown users are ignored
        if logger
          logger.info  "MailHandler: ignoring email from unknown user [#{sender_email}]"
        end
        return false
      end
    end
    User.current = @user
    dispatch
  end

  private

  MESSAGE_ID_RE = %r{^<?redmine\.([a-z0-9_]+)\-(\d+)\.\d+(\.[a-f0-9]+)?@}
  ISSUE_REPLY_SUBJECT_RE = %r{\[(?:[^\]]*\s+)?#(\d+)\]}
  MESSAGE_REPLY_SUBJECT_RE = %r{\[[^\]]*msg(\d+)\]}

  def dispatch
    headers = [email.in_reply_to, email.references].flatten.compact
    subject = email.subject.to_s
    if headers.detect {|h| h.to_s =~ MESSAGE_ID_RE}
      klass, object_id = $1, $2.to_i
      method_name = "receive_#{klass}_reply"
      if self.class.private_instance_methods.collect(&:to_s).include?(method_name)
        send method_name, object_id
      else
        # ignoring it
      end
    elsif m = subject.match(ISSUE_REPLY_SUBJECT_RE)
      receive_issue_reply(m[1].to_i)
    elsif m = subject.match(MESSAGE_REPLY_SUBJECT_RE)
      receive_message_reply(m[1].to_i)
    else
      dispatch_to_default
    end
  rescue ActiveRecord::RecordInvalid => e
    # TODO: send a email to the user
    logger.error "MailHandler: #{e.message}" if logger
    false
  rescue MissingInformation => e
    logger.error "MailHandler: missing information from #{user}: #{e.message}" if logger
    false
  rescue UnauthorizedAction => e
    logger.error "MailHandler: unauthorized attempt from #{user}" if logger
    false
  end

  def dispatch_to_default
    receive_issue
  end

  # Creates a new issue
  def receive_issue
    project = target_project
    # check permission
    unless handler_options[:no_permission_check]
      raise UnauthorizedAction unless user.allowed_to?(:add_issues, project)
    end

    issue = Issue.new(:author => user, :project => project)
    attributes = issue_attributes_from_keywords(issue)
    if handler_options[:no_permission_check]
      issue.tracker_id = attributes['tracker_id']
      if project
        issue.tracker_id ||= project.trackers.first.try(:id)
      end
    end
    issue.safe_attributes = attributes
    issue.safe_attributes = {'custom_field_values' => custom_field_values_from_keywords(issue)}
    issue.subject = cleaned_up_subject
    if issue.subject.blank?
      issue.subject = '(no subject)'
    end
    issue.description = cleaned_up_text_body
    issue.start_date ||= User.current.today if Setting.default_issue_start_date_to_creation_date?
    issue.is_private = (handler_options[:issue][:is_private] == '1')

    # add To and Cc as watchers before saving so the watchers can reply to Redmine
    add_watchers(issue)
    issue.save!
    add_attachments(issue)
    logger.info "MailHandler: issue ##{issue.id} created by #{user}" if logger
    issue
  end

  # Adds a note to an existing issue
  def receive_issue_reply(issue_id, from_journal=nil)
    issue = Issue.find_by_id(issue_id)
    return unless issue
    # check permission
    unless handler_options[:no_permission_check]
      unless user.allowed_to?(:add_issue_notes, issue.project) ||
               user.allowed_to?(:edit_issues, issue.project)
        raise UnauthorizedAction
      end
    end

    # ignore CLI-supplied defaults for new issues
    handler_options[:issue] = {}

    journal = issue.init_journal(user)
    if from_journal && from_journal.private_notes?
      # If the received email was a reply to a private note, make the added note private
      issue.private_notes = true
    end
    issue.safe_attributes = issue_attributes_from_keywords(issue)
    issue.safe_attributes = {'custom_field_values' => custom_field_values_from_keywords(issue)}
    journal.notes = cleaned_up_text_body

    # add To and Cc as watchers before saving so the watchers can reply to Redmine
    add_watchers(issue)
    issue.save!
    add_attachments(issue)
    if logger
      logger.info "MailHandler: issue ##{issue.id} updated by #{user}"
    end
    journal
  end

  # Reply will be added to the issue
  def receive_journal_reply(journal_id)
    journal = Journal.find_by_id(journal_id)
    if journal && journal.journalized_type == 'Issue'
      receive_issue_reply(journal.journalized_id, journal)
    end
  end

  # Receives a reply to a forum message
  def receive_message_reply(message_id)
    message = Message.find_by_id(message_id)
    if message
      message = message.root

      unless handler_options[:no_permission_check]
        raise UnauthorizedAction unless user.allowed_to?(:add_messages, message.project)
      end

      if !message.locked?
        reply = Message.new(:subject => cleaned_up_subject.gsub(%r{^.*msg\d+\]}, '').strip,
                            :content => cleaned_up_text_body)
        reply.author = user
        reply.board = message.board
        message.children << reply
        add_attachments(reply)
        reply
      else
        if logger
          logger.info "MailHandler: ignoring reply from [#{email.from.first}] to a locked topic"
        end
      end
    end
  end

  def add_attachments(obj)
    if email.attachments && email.attachments.any?
      email.attachments.each do |attachment|
        next unless accept_attachment?(attachment)
        next unless attachment.body.decoded.size > 0
        obj.attachments << Attachment.create(:container => obj,
                          :file => attachment.body.decoded,
                          :filename => attachment.filename,
                          :author => user,
                          :content_type => attachment.mime_type)
      end
    end
  end

  # Returns false if the +attachment+ of the incoming email should be ignored
  def accept_attachment?(attachment)
    @excluded ||= Setting.mail_handler_excluded_filenames.to_s.split(',').map(&:strip).reject(&:blank?)
    @excluded.each do |pattern|
      if Setting.mail_handler_enable_regex_excluded_filenames?
        regexp = %r{\A#{pattern}\z}i
      else
        regexp = %r{\A#{Regexp.escape(pattern).gsub("\\*", ".*")}\z}i
      end
      if attachment.filename.to_s =~ regexp
        logger.info "MailHandler: ignoring attachment #{attachment.filename} matching #{pattern}"
        return false
      end
    end
    true
  end

  # Adds To and Cc as watchers of the given object if the sender has the
  # appropriate permission
  def add_watchers(obj)
    if handler_options[:no_permission_check] || user.allowed_to?("add_#{obj.class.name.underscore}_watchers".to_sym, obj.project)
      addresses = [email.to, email.cc].flatten.compact.uniq.collect {|a| a.strip.downcase}
      unless addresses.empty?
        users = User.active.having_mail(addresses).to_a
        users -= obj.watcher_users
        users.each do |u|
          obj.add_watcher(u)
        end
      end
    end
  end

  def get_keyword(attr, options={})
    @keywords ||= {}
    if @keywords.has_key?(attr)
      @keywords[attr]
    else
      @keywords[attr] = begin
        override = options.key?(:override) ?
          options[:override] :
          (handler_options[:allow_override] & [attr.to_s.downcase.gsub(/\s+/, '_'), 'all']).present?

        if override && (v = extract_keyword!(cleaned_up_text_body, attr, options[:format]))
          v
        elsif !handler_options[:issue][attr].blank?
          handler_options[:issue][attr]
        end
      end
    end
  end

  # Destructively extracts the value for +attr+ in +text+
  # Returns nil if no matching keyword found
  def extract_keyword!(text, attr, format=nil)
    keys = [attr.to_s.humanize]
    if attr.is_a?(Symbol)
      if user && user.language.present?
        keys << l("field_#{attr}", :default => '', :locale =>  user.language)
      end
      if Setting.default_language.present?
        keys << l("field_#{attr}", :default => '', :locale =>  Setting.default_language)
      end
    end
    keys.reject! {|k| k.blank?}
    keys.collect! {|k| Regexp.escape(k)}
    format ||= '.+'
    keyword = nil
    regexp = /^(#{keys.join('|')})[ \t]*:[ \t]*(#{format})\s*$/i
    if m = text.match(regexp)
      keyword = m[2].strip
      text.sub!(regexp, '')
    end
    keyword
  end

  def get_project_from_receiver_addresses
    local, domain = handler_options[:project_from_subaddress].to_s.split("@")
    return nil unless local && domain
    local = Regexp.escape(local)

    [:to, :cc, :bcc].each do |field|
      header = @email[field]
      next if header.blank? || header.field.blank? || !header.field.respond_to?(:addrs)
      header.field.addrs.each do |addr|
        if addr.domain.to_s.casecmp(domain)==0 && addr.local.to_s =~ /\A#{local}\+([^+]+)\z/
          if project = Project.find_by_identifier($1)
            return project
          end
        end
      end
    end
    nil
  end

  def target_project
    # TODO: other ways to specify project:
    # * parse the email To field
    # * specific project (eg. Setting.mail_handler_target_project)
    target = get_project_from_receiver_addresses
    target ||= Project.find_by_identifier(get_keyword(:project))
    if target.nil?
      # Invalid project keyword, use the project specified as the default one
      default_project = handler_options[:issue][:project]
      if default_project.present?
        target = Project.find_by_identifier(default_project)
      end
    end
    raise MissingInformation.new('Unable to determine target project') if target.nil?
    target
  end

  # Returns a Hash of issue attributes extracted from keywords in the email body
  def issue_attributes_from_keywords(issue)
    attrs = {
      'tracker_id' => (k = get_keyword(:tracker)) && issue.project.trackers.named(k).first.try(:id),
      'status_id' =>  (k = get_keyword(:status)) && IssueStatus.named(k).first.try(:id),
      'priority_id' => (k = get_keyword(:priority)) && IssuePriority.named(k).first.try(:id),
      'category_id' => (k = get_keyword(:category)) && issue.project.issue_categories.named(k).first.try(:id),
      'assigned_to_id' => (k = get_keyword(:assigned_to)) && find_assignee_from_keyword(k, issue).try(:id),
      'fixed_version_id' => (k = get_keyword(:fixed_version)) && issue.project.shared_versions.named(k).first.try(:id),
      'start_date' => get_keyword(:start_date, :format => '\d{4}-\d{2}-\d{2}'),
      'due_date' => get_keyword(:due_date, :format => '\d{4}-\d{2}-\d{2}'),
      'estimated_hours' => get_keyword(:estimated_hours),
      'done_ratio' => get_keyword(:done_ratio, :format => '(\d|10)?0'),
      'parent_issue_id' => get_keyword(:parent_issue)
    }.delete_if {|k, v| v.blank? }

    attrs
  end

  # Returns a Hash of issue custom field values extracted from keywords in the email body
  def custom_field_values_from_keywords(customized)
    customized.custom_field_values.inject({}) do |h, v|
      if keyword = get_keyword(v.custom_field.name)
        h[v.custom_field.id.to_s] = v.custom_field.value_from_keyword(keyword, customized)
      end
      h
    end
  end

  # Returns the text/plain part of the email
  # If not found (eg. HTML-only email), returns the body with tags removed
  def plain_text_body
    return @plain_text_body unless @plain_text_body.nil?

    # check if we have any plain-text parts with content
    @plain_text_body = email_parts_to_text(email.all_parts.select {|p| p.mime_type == 'text/plain'}).presence

    # if not, we try to parse the body from the HTML-parts
    @plain_text_body ||= email_parts_to_text(email.all_parts.select {|p| p.mime_type == 'text/html'}).presence

    # If there is still no body found, and there are no mime-parts defined,
    # we use the whole raw mail body
    @plain_text_body ||= email_parts_to_text([email]).presence if email.all_parts.empty?

    # As a fallback we return an empty plain text body (e.g. if we have only
    # empty text parts but a non-text attachment)
    @plain_text_body ||= ""
  end

  def email_parts_to_text(parts)
    parts.reject! do |part|
      part.attachment?
    end

    parts.map do |p|
      body_charset = Mail::RubyVer.respond_to?(:pick_encoding) ?
                       Mail::RubyVer.pick_encoding(p.charset).to_s : p.charset

      body = Redmine::CodesetUtil.to_utf8(p.body.decoded, body_charset)
      # convert html parts to text
      p.mime_type == 'text/html' ? self.class.html_body_to_text(body) : self.class.plain_text_body_to_text(body)
    end.join("\r\n")
  end

  def cleaned_up_text_body
    @cleaned_up_text_body ||= cleanup_body(plain_text_body)
  end

  def cleaned_up_subject
    subject = email.subject.to_s
    subject.strip[0,255]
  end

  # Converts a HTML email body to text
  def self.html_body_to_text(html)
    Redmine::WikiFormatting.html_parser.to_text(html)
  end

  # Converts a plain/text email body to text
  def self.plain_text_body_to_text(text)
    # Removes leading spaces that would cause the line to be rendered as
    # preformatted text with textile
    text.gsub(/^ +(?![*#])/, '')
  end

  def self.assign_string_attribute_with_limit(object, attribute, value, limit=nil)
    limit ||= object.class.columns_hash[attribute.to_s].limit || 255
    value = value.to_s.slice(0, limit)
    object.send("#{attribute}=", value)
  end

  # Returns a User from an email address and a full name
  def self.new_user_from_attributes(email_address, fullname=nil)
    user = User.new

    # Truncating the email address would result in an invalid format
    user.mail = email_address
    assign_string_attribute_with_limit(user, 'login', email_address, User::LOGIN_LENGTH_LIMIT)

    names = fullname.blank? ? email_address.gsub(/@.*$/, '').split('.') : fullname.split
    assign_string_attribute_with_limit(user, 'firstname', names.shift, 30)
    assign_string_attribute_with_limit(user, 'lastname', names.join(' '), 30)
    user.lastname = '-' if user.lastname.blank?
    user.language = Setting.default_language
    user.generate_password = true
    user.mail_notification = 'only_my_events'

    unless user.valid?
      user.login = "user#{Redmine::Utils.random_hex(6)}" unless user.errors[:login].blank?
      user.firstname = "-" unless user.errors[:firstname].blank?
      (puts user.errors[:lastname];user.lastname  = "-") unless user.errors[:lastname].blank?
    end

    user
  end

  # Creates a User for the +email+ sender
  # Returns the user or nil if it could not be created
  def create_user_from_email
    from = email.header['from'].to_s
    addr, name = from, nil
    if m = from.match(/^"?(.+?)"?\s+<(.+@.+)>$/)
      addr, name = m[2], m[1]
    end
    if addr.present?
      user = self.class.new_user_from_attributes(addr, name)
      if handler_options[:no_notification]
        user.mail_notification = 'none'
      end
      if user.save
        user
      else
        logger.error "MailHandler: failed to create User: #{user.errors.full_messages}" if logger
        nil
      end
    else
      logger.error "MailHandler: failed to create User: no FROM address found" if logger
      nil
    end
  end

  # Adds the newly created user to default group
  def add_user_to_group(default_group)
    if default_group.present?
      default_group.split(',').each do |group_name|
        if group = Group.named(group_name).first
          group.users << @user
        elsif logger
          logger.warn "MailHandler: could not add user to [#{group_name}], group not found"
        end
      end
    end
  end

  # Removes the email body of text after the truncation configurations.
  def cleanup_body(body)
    delimiters = Setting.mail_handler_body_delimiters.to_s.split(/[\r\n]+/).reject(&:blank?)

    if Setting.mail_handler_enable_regex_delimiters?
      begin
        delimiters = delimiters.map {|s| Regexp.new(s)}
      rescue RegexpError => e
        logger.error "MailHandler: invalid regexp delimiter found in mail_handler_body_delimiters setting (#{e.message})" if logger
      end
    end

    unless delimiters.empty?
      regex = Regexp.new("^[> ]*(#{ Regexp.union(delimiters) })[[:blank:]]*[\r\n].*", Regexp::MULTILINE)
      body = body.gsub(regex, '')
    end
    body.strip
  end

  def find_assignee_from_keyword(keyword, issue)
    Principal.detect_by_keyword(issue.assignable_users, keyword)
  end
end
