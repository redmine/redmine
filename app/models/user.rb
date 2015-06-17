# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

require "digest/sha1"

class User < Principal
  include Redmine::SafeAttributes

  # Different ways of displaying/sorting users
  USER_FORMATS = {
    :firstname_lastname => {
        :string => '#{firstname} #{lastname}',
        :order => %w(firstname lastname id),
        :setting_order => 1
      },
    :firstname_lastinitial => {
        :string => '#{firstname} #{lastname.to_s.chars.first}.',
        :order => %w(firstname lastname id),
        :setting_order => 2
      },
    :firstinitial_lastname => {
        :string => '#{firstname.to_s.gsub(/(([[:alpha:]])[[:alpha:]]*\.?)/, \'\2.\')} #{lastname}',
        :order => %w(firstname lastname id),
        :setting_order => 2
      },
    :firstname => {
        :string => '#{firstname}',
        :order => %w(firstname id),
        :setting_order => 3
      },
    :lastname_firstname => {
        :string => '#{lastname} #{firstname}',
        :order => %w(lastname firstname id),
        :setting_order => 4
      },
    :lastname_coma_firstname => {
        :string => '#{lastname}, #{firstname}',
        :order => %w(lastname firstname id),
        :setting_order => 5
      },
    :lastname => {
        :string => '#{lastname}',
        :order => %w(lastname id),
        :setting_order => 6
      },
    :username => {
        :string => '#{login}',
        :order => %w(login id),
        :setting_order => 7
      },
  }

  MAIL_NOTIFICATION_OPTIONS = [
    ['all', :label_user_mail_option_all],
    ['selected', :label_user_mail_option_selected],
    ['only_my_events', :label_user_mail_option_only_my_events],
    ['only_assigned', :label_user_mail_option_only_assigned],
    ['only_owner', :label_user_mail_option_only_owner],
    ['none', :label_user_mail_option_none]
  ]

  has_and_belongs_to_many :groups,
                          :join_table   => "#{table_name_prefix}groups_users#{table_name_suffix}",
                          :after_add    => Proc.new {|user, group| group.user_added(user)},
                          :after_remove => Proc.new {|user, group| group.user_removed(user)}
  has_many :changesets, :dependent => :nullify
  has_one :preference, :dependent => :destroy, :class_name => 'UserPreference'
  has_one :rss_token, lambda {where "action='feeds'"}, :class_name => 'Token'
  has_one :api_token, lambda {where "action='api'"}, :class_name => 'Token'
  has_one :email_address, lambda {where :is_default => true}, :autosave => true
  has_many :email_addresses, :dependent => :delete_all
  belongs_to :auth_source

  scope :logged, lambda { where("#{User.table_name}.status <> #{STATUS_ANONYMOUS}") }
  scope :status, lambda {|arg| where(arg.blank? ? nil : {:status => arg.to_i}) }

  acts_as_customizable

  attr_accessor :password, :password_confirmation, :generate_password
  attr_accessor :last_before_login_on
  # Prevents unauthorized assignments
  attr_protected :login, :admin, :password, :password_confirmation, :hashed_password

  LOGIN_LENGTH_LIMIT = 60
  MAIL_LENGTH_LIMIT = 60

  validates_presence_of :login, :firstname, :lastname, :if => Proc.new { |user| !user.is_a?(AnonymousUser) }
  validates_uniqueness_of :login, :if => Proc.new { |user| user.login_changed? && user.login.present? }, :case_sensitive => false
  # Login must contain letters, numbers, underscores only
  validates_format_of :login, :with => /\A[a-z0-9_\-@\.]*\z/i
  validates_length_of :login, :maximum => LOGIN_LENGTH_LIMIT
  validates_length_of :firstname, :lastname, :maximum => 30
  validates_inclusion_of :mail_notification, :in => MAIL_NOTIFICATION_OPTIONS.collect(&:first), :allow_blank => true
  validate :validate_password_length
  validate do
    if password_confirmation && password != password_confirmation
      errors.add(:password, :confirmation)
    end
  end

  before_validation :instantiate_email_address
  before_create :set_mail_notification
  before_save   :generate_password_if_needed, :update_hashed_password
  before_destroy :remove_references_before_destroy
  after_save :update_notified_project_ids, :destroy_tokens

  scope :in_group, lambda {|group|
    group_id = group.is_a?(Group) ? group.id : group.to_i
    where("#{User.table_name}.id IN (SELECT gu.user_id FROM #{table_name_prefix}groups_users#{table_name_suffix} gu WHERE gu.group_id = ?)", group_id)
  }
  scope :not_in_group, lambda {|group|
    group_id = group.is_a?(Group) ? group.id : group.to_i
    where("#{User.table_name}.id NOT IN (SELECT gu.user_id FROM #{table_name_prefix}groups_users#{table_name_suffix} gu WHERE gu.group_id = ?)", group_id)
  }
  scope :sorted, lambda { order(*User.fields_for_order_statement)}
  scope :having_mail, lambda {|arg|
    addresses = Array.wrap(arg).map {|a| a.to_s.downcase}
    if addresses.any?
      joins(:email_addresses).where("LOWER(#{EmailAddress.table_name}.address) IN (?)", addresses).uniq
    else
      none
    end
  }

  def set_mail_notification
    self.mail_notification = Setting.default_notification_option if self.mail_notification.blank?
    true
  end

  def update_hashed_password
    # update hashed_password if password was set
    if self.password && self.auth_source_id.blank?
      salt_password(password)
    end
  end

  alias :base_reload :reload
  def reload(*args)
    @name = nil
    @projects_by_role = nil
    @membership_by_project_id = nil
    @notified_projects_ids = nil
    @notified_projects_ids_changed = false
    @builtin_role = nil
    @visible_project_ids = nil
    @managed_roles = nil
    base_reload(*args)
  end

  def mail
    email_address.try(:address)
  end

  def mail=(arg)
    email = email_address || build_email_address
    email.address = arg
  end

  def mail_changed?
    email_address.try(:address_changed?)
  end

  def mails
    email_addresses.pluck(:address)
  end

  def self.find_or_initialize_by_identity_url(url)
    user = where(:identity_url => url).first
    unless user
      user = User.new
      user.identity_url = url
    end
    user
  end

  def identity_url=(url)
    if url.blank?
      write_attribute(:identity_url, '')
    else
      begin
        write_attribute(:identity_url, OpenIdAuthentication.normalize_identifier(url))
      rescue OpenIdAuthentication::InvalidOpenId
        # Invalid url, don't save
      end
    end
    self.read_attribute(:identity_url)
  end

  # Returns the user that matches provided login and password, or nil
  def self.try_to_login(login, password, active_only=true)
    login = login.to_s
    password = password.to_s

    # Make sure no one can sign in with an empty login or password
    return nil if login.empty? || password.empty?
    user = find_by_login(login)
    if user
      # user is already in local database
      return nil unless user.check_password?(password)
      return nil if !user.active? && active_only
    else
      # user is not yet registered, try to authenticate with available sources
      attrs = AuthSource.authenticate(login, password)
      if attrs
        user = new(attrs)
        user.login = login
        user.language = Setting.default_language
        if user.save
          user.reload
          logger.info("User '#{user.login}' created from external auth source: #{user.auth_source.type} - #{user.auth_source.name}") if logger && user.auth_source
        end
      end
    end
    user.update_column(:last_login_on, Time.now) if user && !user.new_record? && user.active?
    user
  rescue => text
    raise text
  end

  # Returns the user who matches the given autologin +key+ or nil
  def self.try_to_autologin(key)
    user = Token.find_active_user('autologin', key, Setting.autologin.to_i)
    if user
      user.update_column(:last_login_on, Time.now)
      user
    end
  end

  def self.name_formatter(formatter = nil)
    USER_FORMATS[formatter || Setting.user_format] || USER_FORMATS[:firstname_lastname]
  end

  # Returns an array of fields names than can be used to make an order statement for users
  # according to how user names are displayed
  # Examples:
  #
  #   User.fields_for_order_statement              => ['users.login', 'users.id']
  #   User.fields_for_order_statement('authors')   => ['authors.login', 'authors.id']
  def self.fields_for_order_statement(table=nil)
    table ||= table_name
    name_formatter[:order].map {|field| "#{table}.#{field}"}
  end

  # Return user's full name for display
  def name(formatter = nil)
    f = self.class.name_formatter(formatter)
    if formatter
      eval('"' + f[:string] + '"')
    else
      @name ||= eval('"' + f[:string] + '"')
    end
  end

  def active?
    self.status == STATUS_ACTIVE
  end

  def registered?
    self.status == STATUS_REGISTERED
  end

  def locked?
    self.status == STATUS_LOCKED
  end

  def activate
    self.status = STATUS_ACTIVE
  end

  def register
    self.status = STATUS_REGISTERED
  end

  def lock
    self.status = STATUS_LOCKED
  end

  def activate!
    update_attribute(:status, STATUS_ACTIVE)
  end

  def register!
    update_attribute(:status, STATUS_REGISTERED)
  end

  def lock!
    update_attribute(:status, STATUS_LOCKED)
  end

  # Returns true if +clear_password+ is the correct user's password, otherwise false
  def check_password?(clear_password)
    if auth_source_id.present?
      auth_source.authenticate(self.login, clear_password)
    else
      User.hash_password("#{salt}#{User.hash_password clear_password}") == hashed_password
    end
  end

  # Generates a random salt and computes hashed_password for +clear_password+
  # The hashed password is stored in the following form: SHA1(salt + SHA1(password))
  def salt_password(clear_password)
    self.salt = User.generate_salt
    self.hashed_password = User.hash_password("#{salt}#{User.hash_password clear_password}")
    self.passwd_changed_on = Time.now.change(:usec => 0)
  end

  # Does the backend storage allow this user to change their password?
  def change_password_allowed?
    return true if auth_source.nil?
    return auth_source.allow_password_changes?
  end

  # Returns true if the user password has expired
  def password_expired?
    period = Setting.password_max_age.to_i
    if period.zero?
      false
    else
      changed_on = self.passwd_changed_on || Time.at(0)
      changed_on < period.days.ago
    end
  end

  def must_change_password?
    (must_change_passwd? || password_expired?) && change_password_allowed?
  end

  def generate_password?
    generate_password == '1' || generate_password == true
  end

  # Generate and set a random password on given length
  def random_password(length=40)
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    chars -= %w(0 O 1 l)
    password = ''
    length.times {|i| password << chars[SecureRandom.random_number(chars.size)] }
    self.password = password
    self.password_confirmation = password
    self
  end

  def pref
    self.preference ||= UserPreference.new(:user => self)
  end

  def time_zone
    @time_zone ||= (self.pref.time_zone.blank? ? nil : ActiveSupport::TimeZone[self.pref.time_zone])
  end

  def force_default_language?
    Setting.force_default_language_for_loggedin?
  end

  def language
    if force_default_language?
      Setting.default_language
    else
      super
    end
  end

  def wants_comments_in_reverse_order?
    self.pref[:comments_sorting] == 'desc'
  end

  # Return user's RSS key (a 40 chars long string), used to access feeds
  def rss_key
    if rss_token.nil?
      create_rss_token(:action => 'feeds')
    end
    rss_token.value
  end

  # Return user's API key (a 40 chars long string), used to access the API
  def api_key
    if api_token.nil?
      create_api_token(:action => 'api')
    end
    api_token.value
  end

  # Return an array of project ids for which the user has explicitly turned mail notifications on
  def notified_projects_ids
    @notified_projects_ids ||= memberships.select {|m| m.mail_notification?}.collect(&:project_id)
  end

  def notified_project_ids=(ids)
    @notified_projects_ids_changed = true
    @notified_projects_ids = ids.map(&:to_i).uniq.select {|n| n > 0}
  end

  # Updates per project notifications (after_save callback)
  def update_notified_project_ids
    if @notified_projects_ids_changed
      ids = (mail_notification == 'selected' ? Array.wrap(notified_projects_ids).reject(&:blank?) : [])
      members.update_all(:mail_notification => false)
      members.where(:project_id => ids).update_all(:mail_notification => true) if ids.any?
    end
  end
  private :update_notified_project_ids

  def valid_notification_options
    self.class.valid_notification_options(self)
  end

  # Only users that belong to more than 1 project can select projects for which they are notified
  def self.valid_notification_options(user=nil)
    # Note that @user.membership.size would fail since AR ignores
    # :include association option when doing a count
    if user.nil? || user.memberships.length < 1
      MAIL_NOTIFICATION_OPTIONS.reject {|option| option.first == 'selected'}
    else
      MAIL_NOTIFICATION_OPTIONS
    end
  end

  # Find a user account by matching the exact login and then a case-insensitive
  # version.  Exact matches will be given priority.
  def self.find_by_login(login)
    login = Redmine::CodesetUtil.replace_invalid_utf8(login.to_s)
    if login.present?
      # First look for an exact match
      user = where(:login => login).detect {|u| u.login == login}
      unless user
        # Fail over to case-insensitive if none was found
        user = where("LOWER(login) = ?", login.downcase).first
      end
      user
    end
  end

  def self.find_by_rss_key(key)
    Token.find_active_user('feeds', key)
  end

  def self.find_by_api_key(key)
    Token.find_active_user('api', key)
  end

  # Makes find_by_mail case-insensitive
  def self.find_by_mail(mail)
    having_mail(mail).first
  end

  # Returns true if the default admin account can no longer be used
  def self.default_admin_account_changed?
    !User.active.find_by_login("admin").try(:check_password?, "admin")
  end

  def to_s
    name
  end

  CSS_CLASS_BY_STATUS = {
    STATUS_ANONYMOUS  => 'anon',
    STATUS_ACTIVE     => 'active',
    STATUS_REGISTERED => 'registered',
    STATUS_LOCKED     => 'locked'
  }

  def css_classes
    "user #{CSS_CLASS_BY_STATUS[status]}"
  end

  # Returns the current day according to user's time zone
  def today
    if time_zone.nil?
      Date.today
    else
      Time.now.in_time_zone(time_zone).to_date
    end
  end

  # Returns the day of +time+ according to user's time zone
  def time_to_date(time)
    if time_zone.nil?
      time.to_date
    else
      time.in_time_zone(time_zone).to_date
    end
  end

  def logged?
    true
  end

  def anonymous?
    !logged?
  end

  # Returns user's membership for the given project
  # or nil if the user is not a member of project
  def membership(project)
    project_id = project.is_a?(Project) ? project.id : project

    @membership_by_project_id ||= Hash.new {|h, project_id|
      h[project_id] = memberships.where(:project_id => project_id).first
    }
    @membership_by_project_id[project_id]
  end

  # Returns the user's bult-in role
  def builtin_role
    @builtin_role ||= Role.non_member
  end

  # Return user's roles for project
  def roles_for_project(project)
    # No role on archived projects
    return [] if project.nil? || project.archived?
    if membership = membership(project)
      membership.roles.dup
    elsif project.is_public?
      project.override_roles(builtin_role)
    else
      []
    end
  end

  # Returns a hash of user's projects grouped by roles
  def projects_by_role
    return @projects_by_role if @projects_by_role

    hash = Hash.new([])

    group_class = anonymous? ? GroupAnonymous : GroupNonMember
    members = Member.joins(:project, :principal).
      where("#{Project.table_name}.status <> 9").
      where("#{Member.table_name}.user_id = ? OR (#{Project.table_name}.is_public = ? AND #{Principal.table_name}.type = ?)", self.id, true, group_class.name).
      preload(:project, :roles).
      to_a

    members.reject! {|member| member.user_id != id && project_ids.include?(member.project_id)}
    members.each do |member|
      if member.project
        member.roles.each do |role|
          hash[role] = [] unless hash.key?(role)
          hash[role] << member.project
        end
      end
    end
    
    hash.each do |role, projects|
      projects.uniq!
    end

    @projects_by_role = hash
  end

  # Returns the ids of visible projects
  def visible_project_ids
    @visible_project_ids ||= Project.visible(self).pluck(:id)
  end

  # Returns the roles that the user is allowed to manage for the given project
  def managed_roles(project)
    if admin?
      @managed_roles ||= Role.givable.to_a
    else
      membership(project).try(:managed_roles) || []
    end
  end

  # Returns true if user is arg or belongs to arg
  def is_or_belongs_to?(arg)
    if arg.is_a?(User)
      self == arg
    elsif arg.is_a?(Group)
      arg.users.include?(self)
    else
      false
    end
  end

  # Return true if the user is allowed to do the specified action on a specific context
  # Action can be:
  # * a parameter-like Hash (eg. :controller => 'projects', :action => 'edit')
  # * a permission Symbol (eg. :edit_project)
  # Context can be:
  # * a project : returns true if user is allowed to do the specified action on this project
  # * an array of projects : returns true if user is allowed on every project
  # * nil with options[:global] set : check if user has at least one role allowed for this action,
  #   or falls back to Non Member / Anonymous permissions depending if the user is logged
  def allowed_to?(action, context, options={}, &block)
    if context && context.is_a?(Project)
      return false unless context.allows_to?(action)
      # Admin users are authorized for anything else
      return true if admin?

      roles = roles_for_project(context)
      return false unless roles
      roles.any? {|role|
        (context.is_public? || role.member?) &&
        role.allowed_to?(action) &&
        (block_given? ? yield(role, self) : true)
      }
    elsif context && context.is_a?(Array)
      if context.empty?
        false
      else
        # Authorize if user is authorized on every element of the array
        context.map {|project| allowed_to?(action, project, options, &block)}.reduce(:&)
      end
    elsif context
      raise ArgumentError.new("#allowed_to? context argument must be a Project, an Array of projects or nil")
    elsif options[:global]
      # Admin users are always authorized
      return true if admin?

      # authorize if user has at least one role that has this permission
      roles = memberships.collect {|m| m.roles}.flatten.uniq
      roles << (self.logged? ? Role.non_member : Role.anonymous)
      roles.any? {|role|
        role.allowed_to?(action) &&
        (block_given? ? yield(role, self) : true)
      }
    else
      false
    end
  end

  # Is the user allowed to do the specified action on any project?
  # See allowed_to? for the actions and valid options.
  #
  # NB: this method is not used anywhere in the core codebase as of
  # 2.5.2, but it's used by many plugins so if we ever want to remove
  # it it has to be carefully deprecated for a version or two.
  def allowed_to_globally?(action, options={}, &block)
    allowed_to?(action, nil, options.reverse_merge(:global => true), &block)
  end

  def allowed_to_view_all_time_entries?(context)
    allowed_to?(:view_time_entries, context) do |role, user|
      role.time_entries_visibility == 'all'
    end
  end

  # Returns true if the user is allowed to delete the user's own account
  def own_account_deletable?
    Setting.unsubscribe? &&
      (!admin? || User.active.where("admin = ? AND id <> ?", true, id).exists?)
  end

  safe_attributes 'login',
    'firstname',
    'lastname',
    'mail',
    'mail_notification',
    'notified_project_ids',
    'language',
    'custom_field_values',
    'custom_fields',
    'identity_url'

  safe_attributes 'status',
    'auth_source_id',
    'generate_password',
    'must_change_passwd',
    :if => lambda {|user, current_user| current_user.admin?}

  safe_attributes 'group_ids',
    :if => lambda {|user, current_user| current_user.admin? && !user.new_record?}

  # Utility method to help check if a user should be notified about an
  # event.
  #
  # TODO: only supports Issue events currently
  def notify_about?(object)
    if mail_notification == 'all'
      true
    elsif mail_notification.blank? || mail_notification == 'none'
      false
    else
      case object
      when Issue
        case mail_notification
        when 'selected', 'only_my_events'
          # user receives notifications for created/assigned issues on unselected projects
          object.author == self || is_or_belongs_to?(object.assigned_to) || is_or_belongs_to?(object.assigned_to_was)
        when 'only_assigned'
          is_or_belongs_to?(object.assigned_to) || is_or_belongs_to?(object.assigned_to_was)
        when 'only_owner'
          object.author == self
        end
      when News
        # always send to project members except when mail_notification is set to 'none'
        true
      end
    end
  end

  def self.current=(user)
    RequestStore.store[:current_user] = user
  end

  def self.current
    RequestStore.store[:current_user] ||= User.anonymous
  end

  # Returns the anonymous user.  If the anonymous user does not exist, it is created.  There can be only
  # one anonymous user per database.
  def self.anonymous
    anonymous_user = AnonymousUser.first
    if anonymous_user.nil?
      anonymous_user = AnonymousUser.create(:lastname => 'Anonymous', :firstname => '', :login => '', :status => 0)
      raise 'Unable to create the anonymous user.' if anonymous_user.new_record?
    end
    anonymous_user
  end

  # Salts all existing unsalted passwords
  # It changes password storage scheme from SHA1(password) to SHA1(salt + SHA1(password))
  # This method is used in the SaltPasswords migration and is to be kept as is
  def self.salt_unsalted_passwords!
    transaction do
      User.where("salt IS NULL OR salt = ''").find_each do |user|
        next if user.hashed_password.blank?
        salt = User.generate_salt
        hashed_password = User.hash_password("#{salt}#{user.hashed_password}")
        User.where(:id => user.id).update_all(:salt => salt, :hashed_password => hashed_password)
      end
    end
  end

  protected

  def validate_password_length
    return if password.blank? && generate_password?
    # Password length validation based on setting
    if !password.nil? && password.size < Setting.password_min_length.to_i
      errors.add(:password, :too_short, :count => Setting.password_min_length.to_i)
    end
  end

  def instantiate_email_address
    email_address || build_email_address
  end

  private

  def generate_password_if_needed
    if generate_password? && auth_source.nil?
      length = [Setting.password_min_length.to_i + 2, 10].max
      random_password(length)
    end
  end

  # Delete all outstanding password reset tokens on password change.
  # Delete the autologin tokens on password change to prohibit session leakage.
  # This helps to keep the account secure in case the associated email account
  # was compromised.
  def destroy_tokens
    if hashed_password_changed?
      tokens = ['recovery', 'autologin']
      Token.where(:user_id => id, :action => tokens).delete_all
    end
  end

  # Removes references that are not handled by associations
  # Things that are not deleted are reassociated with the anonymous user
  def remove_references_before_destroy
    return if self.id.nil?

    substitute = User.anonymous
    Attachment.where(['author_id = ?', id]).update_all(['author_id = ?', substitute.id])
    Comment.where(['author_id = ?', id]).update_all(['author_id = ?', substitute.id])
    Issue.where(['author_id = ?', id]).update_all(['author_id = ?', substitute.id])
    Issue.where(['assigned_to_id = ?', id]).update_all('assigned_to_id = NULL')
    Journal.where(['user_id = ?', id]).update_all(['user_id = ?', substitute.id])
    JournalDetail.
      where(["property = 'attr' AND prop_key = 'assigned_to_id' AND old_value = ?", id.to_s]).
      update_all(['old_value = ?', substitute.id.to_s])
    JournalDetail.
      where(["property = 'attr' AND prop_key = 'assigned_to_id' AND value = ?", id.to_s]).
      update_all(['value = ?', substitute.id.to_s])
    Message.where(['author_id = ?', id]).update_all(['author_id = ?', substitute.id])
    News.where(['author_id = ?', id]).update_all(['author_id = ?', substitute.id])
    # Remove private queries and keep public ones
    ::Query.delete_all ['user_id = ? AND visibility = ?', id, ::Query::VISIBILITY_PRIVATE]
    ::Query.where(['user_id = ?', id]).update_all(['user_id = ?', substitute.id])
    TimeEntry.where(['user_id = ?', id]).update_all(['user_id = ?', substitute.id])
    Token.delete_all ['user_id = ?', id]
    Watcher.delete_all ['user_id = ?', id]
    WikiContent.where(['author_id = ?', id]).update_all(['author_id = ?', substitute.id])
    WikiContent::Version.where(['author_id = ?', id]).update_all(['author_id = ?', substitute.id])
  end

  # Return password digest
  def self.hash_password(clear_password)
    Digest::SHA1.hexdigest(clear_password || "")
  end

  # Returns a 128bits random salt as a hex string (32 chars long)
  def self.generate_salt
    Redmine::Utils.random_hex(16)
  end

end

class AnonymousUser < User
  validate :validate_anonymous_uniqueness, :on => :create

  def validate_anonymous_uniqueness
    # There should be only one AnonymousUser in the database
    errors.add :base, 'An anonymous user already exists.' if AnonymousUser.exists?
  end

  def available_custom_fields
    []
  end

  # Overrides a few properties
  def logged?; false end
  def admin; false end
  def name(*args); I18n.t(:label_user_anonymous) end
  def mail=(*args); nil end
  def mail; nil end
  def time_zone; nil end
  def rss_key; nil end

  def pref
    UserPreference.new(:user => self)
  end

  # Returns the user's bult-in role
  def builtin_role
    @builtin_role ||= Role.anonymous
  end

  def membership(*args)
    nil
  end

  def member_of?(*args)
    false
  end

  # Anonymous user can not be destroyed
  def destroy
    false
  end

  protected

  def instantiate_email_address
  end
end
