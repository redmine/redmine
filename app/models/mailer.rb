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

require 'roadie'

class Mailer < ActionMailer::Base
  layout 'mailer'
  helper :application
  helper :issues
  helper :custom_fields

  include Redmine::I18n
  include Roadie::Rails::Automatic

  # This class wraps multiple generated `Mail::Message` objects and allows to
  # deliver them all at once. It is usually used to handle multiple mails for
  # different receivers created by a single mail event. The wrapped mails can
  # then be delivered in one go.
  #
  # The public interface of the class resembles a single mail message. You can
  # directly use any of the deliver_* methods to send the contained messages
  # now or later.
  class MultiMessage
    attr_reader :mails

    # @param mails [Array<Mail, Proc>] an Array of mails or Procs which create
    #   mail objects and allow to call a method on it.
    def initialize(action, *args)
      @action = action
      @args = args

      @mails = []
    end

    def for(users)
      Array.wrap(users).each do |user|
        @mails << ActionMailer::MessageDelivery.new(Mailer, @action, user, *@args)
      end
      self
    end

    def deliver_later(options = {})
      enqueue_delivery :deliver_now, options
    end

    def deliver_later!(options = {})
      enqueue_delivery :deliver_now!, options
    end

    def processed?
      @mails.any?(&:processed?)
    end

    # @return [Object] the delivery method of the first mail.
    #   Usually, this is the very same value for all mails and matches the
    #   default value of the Mailer class
    def delivery_method
      (@mails.first || ActionMailer::Base::NullMail.new).delivery_method
    end

    # @return [ActionMailer::Base] the delivery handler of the first mail. This
    #   is always the `Mailer` class.
    def delivery_handler
      (@mails.first || ActionMailer::Base::NullMail.new).delivery_handler
    end

    private

    def method_missing(method, *args, &block)
      if method =~ /\Adeliver([_!?]|\z)/
        @mails.each do |mail|
          mail.public_send(method, *args, &block)
        end
      else
        super
      end
    end

    def respond_to_missing(method, *args)
      method =~ /\Adeliver([_!?]|\z)/ || method == 'processed?' || super
    end

    # This method is slightly adapted from ActionMailer::MessageDelivery
    def enqueue_delivery(delivery_method, options = {})
      if processed?
        ::Kernel.raise "You've accessed the message before asking to " \
          "deliver it later, so you may have made local changes that would " \
          "be silently lost if we enqueued a job to deliver it. Why? Only " \
          "the mailer method *arguments* are passed with the delivery job! " \
          "Do not access the message in any way if you mean to deliver it " \
          "later. Workarounds: 1. don't touch the message before calling " \
          "#deliver_later, 2. only touch the message *within your mailer " \
          "method*, or 3. use a custom Active Job instead of #deliver_later."
      else
        args = 'Mailer', @action.to_s, delivery_method.to_s, *@args
        ::ActionMailer::DeliveryJob.set(options).perform_later(*args)
      end
    end
  end

  def process(action, *args)
    user = args.shift
    raise ArgumentError, "First argument has to be a user, was #{user.inspect}" unless user.is_a?(User)

    initial_user = User.current
    initial_language = ::I18n.locale
    begin
      User.current = user

      lang = find_language(user.language) if user.logged?
      lang ||= Setting.default_language
      set_language_if_valid(lang)

      super(action, *args)
    ensure
      User.current = initial_user
      ::I18n.locale = initial_language
    end
  end


  def self.default_url_options
    options = {:protocol => Setting.protocol}
    if Setting.host_name.to_s =~ /\A(https?\:\/\/)?(.+?)(\:(\d+))?(\/.+)?\z/i
      host, port, prefix = $2, $4, $5
      options.merge!({
        :host => host, :port => port, :script_name => prefix
      })
    else
      options[:host] = Setting.host_name
    end
    options
  end

  # Builds a mail for notifying the current user about a new issue
  #
  # Example:
  #   issue_add(issue) => Mail::Message object
  def issue_add(issue)
    redmine_headers 'Project' => issue.project.identifier,
                    'Issue-Id' => issue.id,
                    'Issue-Author' => issue.author.login
    redmine_headers 'Issue-Assignee' => issue.assigned_to.login if issue.assigned_to
    message_id issue
    references issue
    @author = issue.author
    @issue = issue
    @users = [User.current]
    @issue_url = url_for(:controller => 'issues', :action => 'show', :id => issue)
    mail :to => User.current,
      :subject => "[#{issue.project.name} - #{issue.tracker.name} ##{issue.id}] (#{issue.status.name}) #{issue.subject}"
  end

  # Notifies users about a new issue
  #
  # Example:
  #   Mailer.issue_add(journal).deliver => sends emails to the project's recipients
  def self.issue_add(issue)
    users = issue.notified_users | issue.notified_watchers
    MultiMessage.new(:issue_add, issue).for(users)
  end

  # Notifies users about a new issue
  #
  # Example:
  #   Mailer.deliver_issue_add(issue) => sends emails to the project's recipients
  def self.deliver_issue_add(issue)
    issue_add(issue).deliver
  end

  # Builds a mail for notifying the current user about an issue update
  #
  # Example:
  #   issue_edit(journal) => Mail::Message object
  def issue_edit(journal)
    issue = journal.journalized
    redmine_headers 'Project' => issue.project.identifier,
                    'Issue-Id' => issue.id,
                    'Issue-Author' => issue.author.login
    redmine_headers 'Issue-Assignee' => issue.assigned_to.login if issue.assigned_to
    message_id journal
    references issue
    @author = journal.user
    s = "[#{issue.project.name} - #{issue.tracker.name} ##{issue.id}] "
    s << "(#{issue.status.name}) " if journal.new_value_for('status_id')
    s << issue.subject
    @issue = issue
    @users = [User.current]
    @journal = journal
    @journal_details = journal.visible_details
    @issue_url = url_for(:controller => 'issues', :action => 'show', :id => issue, :anchor => "change-#{journal.id}")

    mail :to => User.current,
      :subject => s
  end

  # Build a MultiMessage to notify users about an issue update
  #
  # Example:
  #   Mailer.issue_edit(journal).deliver => sends emails to the project's recipients
  def self.issue_edit(journal)
    users  = journal.notified_users
    users |= journal.notified_watchers
    users.select! do |user|
      journal.notes? || journal.visible_details(user).any?
    end
    MultiMessage.new(:issue_edit, journal).for(users)
  end

  # Notifies users about an issue update
  #
  # Example:
  #   Mailer.deliver_issue_edit(journal) => sends emails to the project's recipients
  def self.deliver_issue_edit(journal)
    issue_edit(journal).deliver
  end

  # Builds a Mail::Message object used to send en email reminder to the current
  # user about their due issues.
  #
  # Example:
  #   reminder(issues, days) => Mail::Message object
  def reminder(issues, days)
    @issues = issues
    @days = days
    @issues_url = url_for(:controller => 'issues', :action => 'index',
                                :set_filter => 1, :assigned_to_id => User.current.id,
                                :sort => 'due_date:asc')
    mail :to => User.current,
      :subject => l(:mail_subject_reminder, :count => issues.size, :days => days)
  end

  # Builds a Mail::Message object used to email the given user about their due
  # issues
  #
  # Example:
  #   Mailer.reminder(user, issues, days, author).deliver => sends an email to the user
  def self.reminder(user, issues, days)
    MultiMessage.new(:reminder, issues, days).for(user)
  end

  # Builds a Mail::Message object used to email the current user that a document
  # was added.
  #
  # Example:
  #   document_added(document, author) => Mail::Message object
  def document_added(document, author)
    redmine_headers 'Project' => document.project.identifier
    @author = author
    @document = document
    @document_url = url_for(:controller => 'documents', :action => 'show', :id => document)
    mail :to => User.current,
      :subject => "[#{document.project.name}] #{l(:label_document_new)}: #{document.title}"
  end

  # Build a MultiMessage to notify users about an added document.
  #
  # Example:
  #   Mailer.document_added(document).deliver => sends emails to the document's project recipients
  def self.document_added(document)
    users = document.notified_users
    MultiMessage.new(:document_added, document, User.current).for(users)
  end

  # Builds a Mail::Message object used to email the current user when
  # attachements are added.
  #
  # Example:
  #   attachments_added(attachments) => Mail::Message object
  def attachments_added(attachments)
    container = attachments.first.container
    added_to = ''
    added_to_url = ''
    @author = attachments.first.author
    case container.class.name
    when 'Project'
      added_to_url = url_for(:controller => 'files', :action => 'index', :project_id => container)
      added_to = "#{l(:label_project)}: #{container}"
    when 'Version'
      added_to_url = url_for(:controller => 'files', :action => 'index', :project_id => container.project)
      added_to = "#{l(:label_version)}: #{container.name}"
    when 'Document'
      added_to_url = url_for(:controller => 'documents', :action => 'show', :id => container.id)
      added_to = "#{l(:label_document)}: #{container.title}"
    end
    redmine_headers 'Project' => container.project.identifier
    @attachments = attachments
    @added_to = added_to
    @added_to_url = added_to_url
    mail :to => User.current,
      :subject => "[#{container.project.name}] #{l(:label_attachment_new)}"
  end

  # Build a MultiMessage to notify users about an added attachment
  #
  # Example:
  #   Mailer.attachments_added(attachments).deliver => sends emails to the project's recipients
  def self.attachments_added(attachments)
    container = attachments.first.container
    case container.class.name
    when 'Project', 'Version'
      users = container.project.notified_users.select {|user| user.allowed_to?(:view_files, container.project)}
    when 'Document'
      users = container.notified_users
    end

    MultiMessage.new(:attachments_added, attachments).for(users)
  end

  # Builds a Mail::Message object used to email the current user when a news
  # item is added.
  #
  # Example:
  #   news_added(news) => Mail::Message object
  def news_added(news)
    redmine_headers 'Project' => news.project.identifier
    @author = news.author
    message_id news
    references news
    @news = news
    @news_url = url_for(:controller => 'news', :action => 'show', :id => news)
    mail :to => User.current,
      :subject => "[#{news.project.name}] #{l(:label_news)}: #{news.title}"
  end

  # Build a MultiMessage to notify users about a new news item
  #
  # Example:
  #   Mailer.news_added(news).deliver => sends emails to the news' project recipients
  def self.news_added(news)
    users = news.notified_users | news.notified_watchers_for_added_news
    MultiMessage.new(:news_added, news).for(users)
  end

  # Builds a Mail::Message object used to email the current user when a news
  # comment is added.
  #
  # Example:
  #   news_comment_added(comment) => Mail::Message object
  def news_comment_added(comment)
    news = comment.commented
    redmine_headers 'Project' => news.project.identifier
    @author = comment.author
    message_id comment
    references news
    @news = news
    @comment = comment
    @news_url = url_for(:controller => 'news', :action => 'show', :id => news)
    mail :to => User.current,
     :subject => "Re: [#{news.project.name}] #{l(:label_news)}: #{news.title}"
  end

  # Build a MultiMessage to notify users about a new news comment
  #
  # Example:
  #   Mailer.news_comment_added(comment).deliver => sends emails to the news' project recipients
  def self.news_comment_added(comment)
    news = comment.commented
    users = news.notified_users | news.notified_watchers

    MultiMessage.new(:news_comment_added, comment).for(users)
  end

  # Builds a Mail::Message object used to email the current user that the
  # specified message was posted.
  #
  # Example:
  #   message_posted(message) => Mail::Message object
  def message_posted(message)
    redmine_headers 'Project' => message.project.identifier,
                    'Topic-Id' => (message.parent_id || message.id)
    @author = message.author
    message_id message
    references message.root
    @message = message
    @message_url = url_for(message.event_url)
    mail :to => User.current,
      :subject => "[#{message.board.project.name} - #{message.board.name} - msg#{message.root.id}] #{message.subject}"
  end

  # Build a MultiMessage to notify users about a new forum message
  #
  # Example:
  #   Mailer.message_posted(message).deliver => sends emails to the recipients
  def self.message_posted(message)
    users  = message.notified_users
    users |= message.root.notified_watchers
    users |= message.board.notified_watchers

    MultiMessage.new(:message_posted, message).for(users)
  end

  # Builds a Mail::Message object used to email the current user that the
  # specified wiki content was added.
  #
  # Example:
  #   wiki_content_added(wiki_content) => Mail::Message object
  def wiki_content_added(wiki_content)
    redmine_headers 'Project' => wiki_content.project.identifier,
                    'Wiki-Page-Id' => wiki_content.page.id
    @author = wiki_content.author
    message_id wiki_content
    @wiki_content = wiki_content
    @wiki_content_url = url_for(:controller => 'wiki', :action => 'show',
                                      :project_id => wiki_content.project,
                                      :id => wiki_content.page.title)
    mail :to => User.current,
      :subject => "[#{wiki_content.project.name}] #{l(:mail_subject_wiki_content_added, :id => wiki_content.page.pretty_title)}"
  end

  # Build a MultiMessage to notify users about added wiki content
  #
  # Example:
  #   Mailer.wiki_content_added(wiki_content).deliver => send emails to the project's recipients
  def self.wiki_content_added(wiki_content)
    users = wiki_content.notified_users | wiki_content.page.wiki.notified_watchers
    MultiMessage.new(:wiki_content_added, wiki_content).for(users)
  end

  # Builds a Mail::Message object used to email the current user about an update
  # of the specified wiki content.
  #
  # Example:
  #   wiki_content_updated(wiki_content) => Mail::Message object
  def wiki_content_updated(wiki_content)
    redmine_headers 'Project' => wiki_content.project.identifier,
                    'Wiki-Page-Id' => wiki_content.page.id
    @author = wiki_content.author
    message_id wiki_content
    @wiki_content = wiki_content
    @wiki_content_url = url_for(:controller => 'wiki', :action => 'show',
                                      :project_id => wiki_content.project,
                                      :id => wiki_content.page.title)
    @wiki_diff_url = url_for(:controller => 'wiki', :action => 'diff',
                                   :project_id => wiki_content.project, :id => wiki_content.page.title,
                                   :version => wiki_content.version)
    mail :to => User.current,
      :subject => "[#{wiki_content.project.name}] #{l(:mail_subject_wiki_content_updated, :id => wiki_content.page.pretty_title)}"
  end

  # Build a MultiMessage to notify users about the update of the specified wiki content
  #
  # Example:
  #   Mailer.wiki_content_updated(wiki_content).deliver => sends an email to the project's recipients
  def self.wiki_content_updated(wiki_content)
    users  = wiki_content.notified_users
    users |= wiki_content.page.notified_watchers
    users |= wiki_content.page.wiki.notified_watchers

    MultiMessage.new(:wiki_content_updated, wiki_content).for(users)
  end

  # Builds a Mail::Message object used to email the current user their account information.
  #
  # Example:
  #   account_information(password) => Mail::Message object
  def account_information(password)
    @user = User.current
    @password = password
    @login_url = url_for(:controller => 'account', :action => 'login')
    mail :to => User.current.mail,
      :subject => l(:mail_subject_register, Setting.app_title)
  end

  # Build a MultiMessage to mail a user their account information
  #
  # Example:
  #   Mailer.account_information(user, password).deliver => sends account information to the user
  def self.account_information(user, password)
    MultiMessage.new(:account_information, password).for(user)
  end

  # Builds a Mail::Message object used to email the current user about an account activation request.
  #
  # Example:
  #   account_activation_request(user) => Mail::Message object
  def account_activation_request(user)
    @user = user
    @url = url_for(:controller => 'users', :action => 'index',
                         :status => User::STATUS_REGISTERED,
                         :sort_key => 'created_on', :sort_order => 'desc')
    mail :to => User.current,
      :subject => l(:mail_subject_account_activation_request, Setting.app_title)
  end

  # Build a MultiMessage to email all active administrators of an account activation request.
  #
  # Example:
  #   Mailer.account_activation_request(user).deliver => sends an email to all active administrators
  def self.account_activation_request(user)
    # Send the email to all active administrators
    users = User.active.where(:admin => true)
    MultiMessage.new(:account_activation_request, user).for(users)
  end

  # Builds a Mail::Message object used to email the account of the current user
  # was activated by an administrator.
  #
  # Example:
  #   account_activated => Mail::Message object
  def account_activated
    @user = User.current
    @login_url = url_for(:controller => 'account', :action => 'login')
    mail :to => User.current.mail,
      :subject => l(:mail_subject_register, Setting.app_title)
  end

  # Build a MultiMessage to email the specified user that their account was
  # activated by an administrator.
  #
  # Example:
  #   Mailer.account_activated(user).deliver => sends an email to the registered user
  def self.account_activated(user)
    MultiMessage.new(:account_activated).for(user)
  end

  # Builds a Mail::Message object used to email the lost password token to the
  # token's user (or a different recipient).
  #
  # Example:
  #   lost_password(token) => Mail::Message object
  def lost_password(token, recipient=nil)
    recipient ||= token.user.mail
    @token = token
    @url = url_for(:controller => 'account', :action => 'lost_password', :token => token.value)
    mail :to => recipient,
      :subject => l(:mail_subject_lost_password, Setting.app_title)
  end

  # Build a MultiMessage to email the token's user (or a different recipient)
  # the lost password token for the token's user.
  #
  # Example:
  #   Mailer.lost_password(token).deliver => sends an email to the user
  def self.lost_password(token, recipient=nil)
    MultiMessage.new(:lost_password, token, recipient).for(token.user)
  end

  # Notifies user that his password was updated
  def self.password_updated(user, options={})
    # Don't send a notification to the dummy email address when changing the password
    # of the default admin account which is required after the first login
    # TODO: maybe not the best way to handle this
    return if user.admin? && user.login == 'admin' && user.mail == 'admin@example.net'

    security_notification(user,
      message: :mail_body_password_updated,
      title: :button_change_password,
      remote_ip: options[:remote_ip],
      originator: user,
      url: {controller: 'my', action: 'password'}
    ).deliver
  end

  # Builds a Mail::Message object used to email the user activation link to the
  # token's user.
  #
  # Example:
  #   register(token) => Mail::Message object
  def register(token)
    @token = token
    @url = url_for(:controller => 'account', :action => 'activate', :token => token.value)
    mail :to => token.user.mail,
      :subject => l(:mail_subject_register, Setting.app_title)
  end

  # Build a MultiMessage to email the user activation link to the token's user.
  #
  # Example:
  #   Mailer.register(token).deliver => sends an email to the token's user
  def self.register(token)
    MultiMessage.new(:register, token).for(token.user)
  end

  # Build a Mail::Message object to email the current user and the additional
  # recipients given in options[:recipients] about a security related event.
  #
  # Example:
  #   security_notification(users,
  #     message: :mail_body_security_notification_add,
  #     field: :field_mail,
  #     value: address
  #   ) => Mail::Message object
  def security_notification(sender, options={})
    @sender = sender
    redmine_headers 'Sender' => sender.login
    @message = l(options[:message],
      field: (options[:field] && l(options[:field])),
      value: options[:value]
    )
    @title = options[:title] && l(options[:title])
    @originator = options[:originator] || sender
    @remote_ip = options[:remote_ip] || @originator.remote_ip
    @url = options[:url] && (options[:url].is_a?(Hash) ? url_for(options[:url]) : options[:url])
    redmine_headers 'Sender' => @originator.login
    redmine_headers 'Url' => @url
    mail :to => [User.current, *options[:recipients]].uniq,
      :subject => "[#{Setting.app_title}] #{l(:mail_subject_security_notification)}"
  end

  # Build a MultiMessage to email the given users about a security related event.
  #
  # You can specify additional recipients in options[:recipients]. These will be
  # added to all generated mails for all given users. Usually, you'll want to
  # give only a single user when setting the additional recipients.
  #
  # Example:
  #   Mailer.security_notification(users,
  #     message: :mail_body_security_notification_add,
  #     field: :field_mail,
  #     value: address
  #   ).deliver => sends a security notification to the given user(s)
  def self.security_notification(users, options={})
    sender = User.current
    MultiMessage.new(:security_notification, sender, options).for(users)
  end

  # Build a Mail::Message object to email the current user about an updated
  # setting.
  #
  # Example:
  #   settings_updated(sender, [:host_name]) => Mail::Message object
  def settings_updated(sender, changes)
    @sender = sender
    redmine_headers 'Sender' => sender.login
    @changes = changes
    @url = url_for(controller: 'settings', action: 'index')
    mail :to => User.current,
      :subject => "[#{Setting.app_title}] #{l(:mail_subject_security_notification)}"
  end

  # Build a MultiMessage to email the given users about an update of a setting.
  #
  # Example:
  #   Mailer.settings_updated(users, [:host_name]).deliver => sends emails to the given user(s) about the update
  def self.settings_updated(users, changes)
    sender = User.current
    MultiMessage.new(:settings_updated, sender, changes).for(users)
  end
  
  # Notifies admins about settings changes
  def self.security_settings_updated(changes)
    return unless changes.present?

    users = User.active.where(admin: true).to_a
    settings_updated(users, changes).deliver
  end

  # Build a Mail::Message object with a test email for the current user
  #
  # Example:
  #   test_email => Mail::Message object
  def test_email
    @url = url_for(:controller => 'welcome')
    mail :to => User.current.mail,
      :subject => 'Redmine test'
  end

  # Build a MultiMessage to send a test email the given user
  #
  # Example:
  #   Mailer.test_email(user).deliver => send an email to the given user
  def self.test_email(user)
    MultiMessage.new(:test_email).for(user)
  end

  # Sends reminders to issue assignees
  # Available options:
  # * :days     => how many days in the future to remind about (defaults to 7)
  # * :tracker  => id of tracker for filtering issues (defaults to all trackers)
  # * :project  => id or identifier of project to process (defaults to all projects)
  # * :users    => array of user/group ids who should be reminded
  # * :version  => name of target version for filtering issues (defaults to none)
  def self.reminders(options={})
    days = options[:days] || 7
    project = options[:project] ? Project.find(options[:project]) : nil
    tracker = options[:tracker] ? Tracker.find(options[:tracker]) : nil
    target_version_id = options[:version] ? Version.named(options[:version]).pluck(:id) : nil
    if options[:version] && target_version_id.blank?
      raise ActiveRecord::RecordNotFound.new("Couldn't find Version named #{options[:version]}")
    end
    user_ids = options[:users]

    scope = Issue.open.where("#{Issue.table_name}.assigned_to_id IS NOT NULL" +
      " AND #{Project.table_name}.status = #{Project::STATUS_ACTIVE}" +
      " AND #{Issue.table_name}.due_date <= ?", days.day.from_now.to_date
    )
    scope = scope.where(:assigned_to_id => user_ids) if user_ids.present?
    scope = scope.where(:project_id => project.id) if project
    scope = scope.where(:fixed_version_id => target_version_id) if target_version_id.present?
    scope = scope.where(:tracker_id => tracker.id) if tracker
    issues_by_assignee = scope.includes(:status, :assigned_to, :project, :tracker).
                              group_by(&:assigned_to)
    issues_by_assignee.keys.each do |assignee|
      if assignee.is_a?(Group)
        assignee.users.each do |user|
          issues_by_assignee[user] ||= []
          issues_by_assignee[user] += issues_by_assignee[assignee]
        end
      end
    end

    issues_by_assignee.each do |assignee, issues|
      if assignee.is_a?(User) && assignee.active? && issues.present?
        visible_issues = issues.select {|i| i.visible?(assignee)}
        reminder(assignee, visible_issues, days).deliver if visible_issues.present?
      end
    end
  end

  # Activates/desactivates email deliveries during +block+
  def self.with_deliveries(enabled = true, &block)
    was_enabled = ActionMailer::Base.perform_deliveries
    ActionMailer::Base.perform_deliveries = !!enabled
    yield
  ensure
    ActionMailer::Base.perform_deliveries = was_enabled
  end

  # Sends emails synchronously in the given block
  def self.with_synched_deliveries(&block)
    saved_method = ActionMailer::Base.delivery_method
    if m = saved_method.to_s.match(%r{^async_(.+)$})
      synched_method = m[1]
      ActionMailer::Base.delivery_method = synched_method.to_sym
      ActionMailer::Base.send "#{synched_method}_settings=", ActionMailer::Base.send("async_#{synched_method}_settings")
    end
    yield
  ensure
    ActionMailer::Base.delivery_method = saved_method
  end

  def mail(headers={}, &block)
    headers.reverse_merge! 'X-Mailer' => 'Redmine',
            'X-Redmine-Host' => Setting.host_name,
            'X-Redmine-Site' => Setting.app_title,
            'X-Auto-Response-Suppress' => 'All',
            'Auto-Submitted' => 'auto-generated',
            'From' => Setting.mail_from,
            'List-Id' => "<#{Setting.mail_from.to_s.tr('@', '.')}>"

    # Replaces users with their email addresses
    [:to, :cc, :bcc].each do |key|
      if headers[key].present?
        headers[key] = self.class.email_addresses(headers[key])
      end
    end

    # Removes the author from the recipients and cc
    # if the author does not want to receive notifications
    # about what the author do
    if @author && @author.logged? && @author.pref.no_self_notified
      addresses = @author.mails
      headers[:to] -= addresses if headers[:to].is_a?(Array)
      headers[:cc] -= addresses if headers[:cc].is_a?(Array)
    end

    if @author && @author.logged?
      redmine_headers 'Sender' => @author.login
    end

    # Blind carbon copy recipients
    if Setting.bcc_recipients?
      headers[:bcc] = [headers[:to], headers[:cc]].flatten.uniq.reject(&:blank?)
      headers[:to] = nil
      headers[:cc] = nil
    end

    if @message_id_object
      headers[:message_id] = "<#{self.class.message_id_for(@message_id_object)}>"
    end
    if @references_objects
      headers[:references] = @references_objects.collect {|o| "<#{self.class.references_for(o)}>"}.join(' ')
    end

    if block_given?
      super headers, &block
    else
      super headers do |format|
        format.text
        format.html unless Setting.plain_text_mail?
      end
    end
  end

  def self.deliver_mail(mail)
    return false if mail.to.blank? && mail.cc.blank? && mail.bcc.blank?
    begin
      # Log errors when raise_delivery_errors is set to false, Rails does not
      mail.raise_delivery_errors = true
      super
    rescue Exception => e
      if ActionMailer::Base.raise_delivery_errors
        raise e
      else
        Rails.logger.error "Email delivery error: #{e.message}"
      end
    end
  end

  def self.method_missing(method, *args, &block)
    if m = method.to_s.match(%r{^deliver_(.+)$})
      ActiveSupport::Deprecation.warn "Mailer.deliver_#{m[1]}(*args) is deprecated. Use Mailer.#{m[1]}(*args).deliver instead."
      send(m[1], *args).deliver
    elsif action_methods.include?(method.to_s)
      MultiMessage.new(method, *args).for(User.current)
    else
      super
    end
  end

  # Returns an array of email addresses to notify by
  # replacing users in arg with their notified email addresses
  #
  # Example:
  #   Mailer.email_addresses(users)
  #   => ["foo@example.net", "bar@example.net"]
  def self.email_addresses(arg)
    arr = Array.wrap(arg)
    mails = arr.reject {|a| a.is_a? Principal}
    users = arr - mails
    if users.any?
      mails += EmailAddress.
        where(:user_id => users.map(&:id)).
        where("is_default = ? OR notify = ?", true, true).
        pluck(:address)
    end
    mails
  end

  private

  # Appends a Redmine header field (name is prepended with 'X-Redmine-')
  def redmine_headers(h)
    h.each { |k,v| headers["X-Redmine-#{k}"] = v.to_s }
  end

  def self.token_for(object, rand=true)
    timestamp = object.send(object.respond_to?(:created_on) ? :created_on : :updated_on)
    hash = [
      "redmine",
      "#{object.class.name.demodulize.underscore}-#{object.id}",
      timestamp.strftime("%Y%m%d%H%M%S")
    ]
    if rand
      hash << Redmine::Utils.random_hex(8)
    end
    host = Setting.mail_from.to_s.strip.gsub(%r{^.*@|>}, '')
    host = "#{::Socket.gethostname}.redmine" if host.empty?
    "#{hash.join('.')}@#{host}"
  end

  # Returns a Message-Id for the given object
  def self.message_id_for(object)
    token_for(object, true)
  end

  # Returns a uniq token for a given object referenced by all notifications
  # related to this object
  def self.references_for(object)
    token_for(object, false)
  end

  def message_id(object)
    @message_id_object = object
  end

  def references(object)
    @references_objects ||= []
    @references_objects << object
  end
end
