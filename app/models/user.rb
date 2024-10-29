# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
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
  include Redmine::Ciphering
  include Redmine::SafeAttributes

  # Different ways of displaying/sorting users
  # rubocop:disable Lint/InterpolationCheck
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
    :lastnamefirstname => {
      :string => '#{lastname}#{firstname}',
      :order => %w(lastname firstname id),
      :setting_order => 5
    },
    :lastname_comma_firstname => {
      :string => '#{lastname}, #{firstname}',
      :order => %w(lastname firstname id),
      :setting_order => 6
    },
    :lastname => {
      :string => '#{lastname}',
      :order => %w(lastname id),
      :setting_order => 7
    },
    :username => {
      :string => '#{login}',
      :order => %w(login id),
      :setting_order => 8
    },
  }
  # rubocop:enable Lint/InterpolationCheck

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
  has_one :atom_token, lambda {where "action='feeds'"}, :class_name => 'Token'
  has_one :api_token, lambda {where "action='api'"}, :class_name => 'Token'
  has_one :email_address, lambda {where :is_default => true}, :autosave => true
  has_many :email_addresses, :dependent => :delete_all
  belongs_to :auth_source

  scope :logged, lambda {where("#{User.table_name}.status <> #{STATUS_ANONYMOUS}")}
  scope :status, lambda {|arg| where(arg.blank? ? nil : {:status => arg.to_i})}

  acts_as_customizable

  attr_accessor :password, :password_confirmation, :generate_password
  attr_accessor :last_before_login_on
  attr_accessor :remote_ip

  LOGIN_LENGTH_LIMIT = 60
  MAIL_LENGTH_LIMIT = 254

  validates_presence_of :login, :firstname, :lastname, :if => Proc.new {|user| !user.is_a?(AnonymousUser)}
  validates_uniqueness_of :login, :if => Proc.new {|user| user.login_changed? && user.login.present?}, :case_sensitive => false
  # Login must contain letters, numbers, underscores only
  validates_format_of :login, :with => /\A[a-z0-9_\-@\.]*\z/i
  validates_length_of :login, :maximum => LOGIN_LENGTH_LIMIT
  validates_length_of :firstname, :maximum => 30
  validates_length_of :lastname, :maximum => 255
  validates_inclusion_of :mail_notification, :in => MAIL_NOTIFICATION_OPTIONS.collect(&:first), :allow_blank => true
  Setting::PASSWORD_CHAR_CLASSES.each do |k, v|
    validates_format_of :password, :with => v, :message => :"must_contain_#{k}", :allow_blank => true, :if => Proc.new {Setting.password_required_char_classes.include?(k)}
  end
  validate :validate_password_length
  validate :validate_password_complexity
  validate do
    if password_confirmation && password != password_confirmation
      errors.add(:password, :confirmation)
    end
  end

  self.valid_statuses = [STATUS_ACTIVE, STATUS_REGISTERED, STATUS_LOCKED]

  before_validation :instantiate_email_address
  before_save   :generate_password_if_needed, :update_hashed_password
  before_create :set_mail_notification
  before_destroy :remove_references_before_destroy
  after_destroy :deliver_security_notification
  after_save :update_notified_project_ids, :destroy_tokens, :deliver_security_notification

  scope :admin, (lambda do |*args|
    admin = args.size > 0 ? !!args.first : true
    where(:admin => admin)
  end)
  scope :in_group, (lambda do |group|
    group_id = group.is_a?(Group) ? group.id : group.to_i
    where("#{User.table_name}.id IN (SELECT gu.user_id FROM #{table_name_prefix}groups_users#{table_name_suffix} gu WHERE gu.group_id = ?)", group_id)
  end)
  scope :not_in_group, (lambda do |group|
    group_id = group.is_a?(Group) ? group.id : group.to_i
    where("#{User.table_name}.id NOT IN (SELECT gu.user_id FROM #{table_name_prefix}groups_users#{table_name_suffix} gu WHERE gu.group_id = ?)", group_id)
  end)
  scope :sorted, lambda {order(*User.fields_for_order_statement)}
  scope :having_mail, (lambda do |arg|
    addresses = Array.wrap(arg).map {|a| a.to_s.downcase}
    if addresses.any?
      joins(:email_addresses).where("LOWER(#{EmailAddress.table_name}.address) IN (?)", addresses).distinct
    else
      none
    end
  end)

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
    @roles = nil
    @projects_by_role = nil
    @project_ids_by_role = nil
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

  # Returns the user that matches provided login and password, or nil
  # AuthSource errors are caught, logged and nil is returned.
  def self.try_to_login(login, password, active_only=true)
    try_to_login!(login, password, active_only)
  rescue AuthSourceException => e
    logger.error "An error occured when authenticating #{login}: #{e.message}"
    nil
  end

  # Returns the user that matches provided login and password, or nil
  # AuthSource errors are passed through.
  def self.try_to_login!(login, password, active_only=true)
    login = login.to_s.strip
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
    user.update_last_login_on! if user && !user.new_record? && user.active?
    user
  end

  # Returns the user who matches the given autologin +key+ or nil
  def self.try_to_autologin(key)
    user = Token.find_active_user('autologin', key, Setting.autologin.to_i)
    if user
      user.update_last_login_on!
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

  def update_last_login_on!
    return if last_login_on.present? && last_login_on >= 1.minute.ago

    update_column(:last_login_on, Time.now)
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
    auth_source.nil? ? true : auth_source.allow_password_changes?
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
    ActiveRecord::Type::Boolean.new.deserialize(generate_password)
  end

  # Generate and set a random password on given length
  def random_password(length=40)
    chars_list = [('A'..'Z').to_a, ('a'..'z').to_a, ('0'..'9').to_a]
    # auto-generated passwords contain special characters only when admins
    # require users to use passwords which contains special characters
    if Setting.password_required_char_classes.include?('special_chars')
      chars_list << ("\x20".."\x7e").to_a.select {|c| c =~ Setting::PASSWORD_CHAR_CLASSES['special_chars']}
    end
    chars_list.each {|v| v.reject! {|c| %(0O1l|'"`*).include?(c)}}

    password = +''
    chars_list.each do |chars|
      password << chars[SecureRandom.random_number(chars.size)]
      length -= 1
    end
    chars = chars_list.flatten
    length.times {password << chars[SecureRandom.random_number(chars.size)]}
    password = password.chars.shuffle(random: SecureRandom).join
    self.password = password
    self.password_confirmation = password
    self
  end

  def twofa_active?
    twofa_scheme.present?
  end

  def must_activate_twofa?
    return false if twofa_active?

    return true if Setting.twofa_required?
    return true if Setting.twofa_required_for_administrators? && admin?
    return true if Setting.twofa_optional? && groups.any?(&:twofa_required?)
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

  # Return user's ATOM key (a 40 chars long string), used to access feeds
  def atom_key
    if atom_token.nil?
      create_atom_token(:action => 'feeds')
    end
    atom_token.value
  end

  # Return user's API key (a 40 chars long string), used to access the API
  def api_key
    if api_token.nil?
      create_api_token(:action => 'api')
    end
    api_token.value
  end

  # Generates a new session token and returns its value
  def generate_session_token
    token = Token.create!(:user_id => id, :action => 'session')
    token.value
  end

  def delete_session_token(value)
    Token.where(:user_id => id, :action => 'session', :value => value).delete_all
  end

  # Generates a new autologin token and returns its value
  def generate_autologin_token
    token = Token.create!(:user_id => id, :action => 'autologin')
    token.value
  end

  def delete_autologin_token(value)
    Token.where(:user_id => id, :action => 'autologin', :value => value).delete_all
  end

  def twofa_totp_key
    read_ciphered_attribute(:twofa_totp_key)
  end

  def twofa_totp_key=(key)
    write_ciphered_attribute(:twofa_totp_key, key)
  end

  # Returns true if token is a valid session token for the user whose id is user_id
  def self.verify_session_token(user_id, token)
    return false if user_id.blank? || token.blank?

    scope = Token.where(:user_id => user_id, :value => token.to_s, :action => 'session')
    if Setting.session_lifetime?
      scope = scope.where("created_on > ?", Setting.session_lifetime.to_i.minutes.ago)
    end
    if Setting.session_timeout?
      scope = scope.where("updated_on > ?", Setting.session_timeout.to_i.minutes.ago)
    end
    last_updated = scope.maximum(:updated_on)
    if last_updated.nil?
      false
    elsif last_updated <= 1.minute.ago
      scope.update_all(:updated_on => Time.now) == 1
    else
      true
    end
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
        user = find_by("LOWER(login) = ?", login.downcase)
      end
      user
    end
  end

  def self.find_by_atom_key(key)
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

  LABEL_BY_STATUS = {
    STATUS_ANONYMOUS  => 'anon',
    STATUS_ACTIVE     => 'active',
    STATUS_REGISTERED => 'registered',
    STATUS_LOCKED     => 'locked'
  }

  def css_classes
    "user #{LABEL_BY_STATUS[status]}"
  end

  # Returns the current day according to user's time zone
  def today
    if time_zone.nil?
      Date.today
    else
      time_zone.today
    end
  end

  # Returns the day of +time+ according to user's time zone
  def time_to_date(time)
    self.convert_time_to_user_timezone(time).to_date
  end

  def convert_time_to_user_timezone(time)
    if self.time_zone
      time.in_time_zone(self.time_zone)
    else
      time.utc? ? time.localtime : time
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

    @membership_by_project_id ||=
      Hash.new do |h, project_id|
        h[project_id] = memberships.where(:project_id => project_id).first
      end
    @membership_by_project_id[project_id]
  end

  def roles
    @roles ||=
      Role.joins(members: :project).
        where(["#{Project.table_name}.status <> ?", Project::STATUS_ARCHIVED]).
          where(Member.arel_table[:user_id].eq(id)).distinct

    if @roles.blank?
      group_class = anonymous? ? GroupAnonymous : GroupNonMember
      @roles = Role.joins(members: :project).
        where(["#{Project.table_name}.status <> ? AND #{Project.table_name}.is_public = ?", Project::STATUS_ARCHIVED, true]).
        where(Member.arel_table[:user_id].eq(group_class.first.id)).distinct
    end

    @roles
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
      membership.roles.to_a
    elsif project.is_public?
      project.override_roles(builtin_role)
    else
      []
    end
  end

  # Returns a hash of user's projects grouped by roles
  # TODO: No longer used, should be deprecated
  def projects_by_role
    return @projects_by_role if @projects_by_role

    result = Hash.new([])
    project_ids_by_role.each do |role, ids|
      result[role] = Project.where(:id => ids).to_a
    end
    @projects_by_role = result
  end

  # Returns a hash of project ids grouped by roles.
  # Includes the projects that the user is a member of and the projects
  # that grant custom permissions to the builtin groups.
  def project_ids_by_role
    # Clear project condition for when called from chained scopes
    # eg. project.children.visible(user)
    Project.unscoped do
      return @project_ids_by_role if @project_ids_by_role

      group_class = anonymous? ? GroupAnonymous.unscoped : GroupNonMember.unscoped
      group_id = group_class.pick(:id)

      members = Member.joins(:project, :member_roles).
        where("#{Project.table_name}.status <> 9").
        where("#{Member.table_name}.user_id = ? OR (#{Project.table_name}.is_public = ? AND #{Member.table_name}.user_id = ?)", self.id, true, group_id).
        pluck(:user_id, :role_id, :project_id)

      hash = {}
      members.each do |user_id, role_id, project_id|
        # Ignore the roles of the builtin group if the user is a member of the project
        next if user_id != id && project_ids.include?(project_id)

        hash[role_id] ||= []
        hash[role_id] << project_id
      end

      result = Hash.new([])
      if hash.present?
        roles = Role.where(:id => hash.keys).to_a
        hash.each do |role_id, proj_ids|
          role = roles.detect {|r| r.id == role_id}
          if role
            result[role] = proj_ids.uniq
          end
        end
      end
      @project_ids_by_role = result
    end
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

      roles.any? do |role|
        (context.is_public? || role.member?) &&
        role.allowed_to?(action) &&
        (block ? yield(role, self) : true)
      end
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
      roles = self.roles.to_a | [builtin_role]
      roles.any? do |role|
        role.allowed_to?(action) &&
        (block ? yield(role, self) : true)
      end
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
  def allowed_to_globally?(action, options={}, &)
    allowed_to?(action, nil, options.reverse_merge(:global => true), &)
  end

  def allowed_to_view_all_time_entries?(context)
    allowed_to?(:view_time_entries, context) do |role, user|
      role.time_entries_visibility == 'all'
    end
  end

  # Returns true if the user is allowed to delete the user's own account
  def own_account_deletable?
    Setting.unsubscribe? &&
      (!admin? || User.active.admin.where("id <> ?", id).exists?)
  end

  safe_attributes(
    'firstname',
    'lastname',
    'mail',
    'mail_notification',
    'notified_project_ids',
    'language',
    'custom_field_values',
    'custom_fields')
  safe_attributes(
    'login',
    :if => lambda {|user, current_user| user.new_record?})
  safe_attributes(
    'status',
    'auth_source_id',
    'generate_password',
    'must_change_passwd',
    'login',
    'admin',
    :if => lambda {|user, current_user| current_user.admin?})
  safe_attributes(
    'group_ids',
    :if => lambda {|user, current_user| current_user.admin? && !user.new_record?})

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
          object.author == self || is_or_belongs_to?(object.assigned_to) || is_or_belongs_to?(object.previous_assignee)
        when 'only_assigned'
          is_or_belongs_to?(object.assigned_to) || is_or_belongs_to?(object.previous_assignee)
        when 'only_owner'
          object.author == self
        end
      when News
        # always send to project members except when mail_notification is set to 'none'
        true
      end
    end
  end

  def notify_about_high_priority_issues?
    self.pref.notify_about_high_priority_issues
  end

  class CurrentUser < ActiveSupport::CurrentAttributes
    attribute :user
  end

  def self.current=(user)
    CurrentUser.user = user
  end

  def self.current
    CurrentUser.user ||= User.anonymous
  end

  # Returns the anonymous user.  If the anonymous user does not exist, it is created.  There can be only
  # one anonymous user per database.
  def self.anonymous
    anonymous_user = AnonymousUser.unscoped.find_by(:lastname => 'Anonymous')
    if anonymous_user.nil?
      anonymous_user = AnonymousUser.unscoped.create(:lastname => 'Anonymous', :firstname => '', :login => '', :status => 0)
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

  def bookmarked_project_ids
    project_ids = []
    bookmarked_project_ids = self.pref[:bookmarked_project_ids]
    project_ids = bookmarked_project_ids.split(',') unless bookmarked_project_ids.nil?
    project_ids.map(&:to_i)
  end

  def self.prune(age=30.days)
    User.where("created_on < ? AND status = ?", Time.now - age, STATUS_REGISTERED).destroy_all
  end

  protected

  def validate_password_length
    return if password.blank? && generate_password?

    # Password length validation based on setting
    if !password.nil? && password.size < Setting.password_min_length.to_i
      errors.add(:password, :too_short, :count => Setting.password_min_length.to_i)
    end
  end

  def validate_password_complexity
    return if password.blank? && generate_password?
    return if password.nil?

    # TODO: Enhance to check for more common and simple passwords
    # like 'password', '123456', 'qwerty', etc.
    bad_passwords = [login, firstname, lastname, mail] + email_addresses.map(&:address)
    errors.add(:password, :too_simple) if bad_passwords.any? {|p| password.casecmp?(p)}
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
    if saved_change_to_hashed_password? || (saved_change_to_status? && !active?) || (saved_change_to_twofa_scheme? && twofa_scheme.present?)
      tokens = ['recovery', 'autologin', 'session']
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
    Journal.where(['updated_by_id = ?', id]).update_all(['updated_by_id = ?', substitute.id])
    JournalDetail.
      where(["property = 'attr' AND prop_key = 'assigned_to_id' AND old_value = ?", id.to_s]).
      update_all(['old_value = ?', substitute.id.to_s])
    JournalDetail.
      where(["property = 'attr' AND prop_key = 'assigned_to_id' AND value = ?", id.to_s]).
      update_all(['value = ?', substitute.id.to_s])
    Message.where(['author_id = ?', id]).update_all(['author_id = ?', substitute.id])
    News.where(['author_id = ?', id]).update_all(['author_id = ?', substitute.id])
    # Remove private queries and keep public ones
    ::Query.where('user_id = ? AND visibility = ?', id, ::Query::VISIBILITY_PRIVATE).delete_all
    ::Query.where(['user_id = ?', id]).update_all(['user_id = ?', substitute.id])
    TimeEntry.where(['user_id = ?', id]).update_all(['user_id = ?', substitute.id])
    Token.where('user_id = ?', id).delete_all
    Watcher.where('user_id = ?', id).delete_all
    WikiContent.where(['author_id = ?', id]).update_all(['author_id = ?', substitute.id])
    WikiContentVersion.where(['author_id = ?', id]).update_all(['author_id = ?', substitute.id])
    user_custom_field_ids = CustomField.where(field_format: 'user').ids
    if user_custom_field_ids.any?
      CustomValue.where(custom_field_id: user_custom_field_ids, value: self.id.to_s).delete_all
    end
  end

  # Singleton class method is public
  class << self
    # Return password digest
    def hash_password(clear_password)
      Digest::SHA1.hexdigest(clear_password || "")
    end

    # Returns a 128bits random salt as a hex string (32 chars long)
    def generate_salt
      Redmine::Utils.random_hex(16)
    end
  end

  # Send a security notification to all admins if the user has gained/lost admin privileges
  def deliver_security_notification
    options = {
      field: :field_admin,
      value: login,
      title: :label_user_plural,
      url: {controller: 'users', action: 'index'}
    }

    deliver = false
    if (admin? && saved_change_to_id? && active?) ||    # newly created admin
       (admin? && saved_change_to_admin? && active?) || # regular user became admin
       (admin? && saved_change_to_status? && active?)   # locked admin became active again
      deliver = true
      options[:message] = :mail_body_security_notification_add
    elsif (admin? && destroyed? && active?) ||      # active admin user was deleted
          (!admin? && saved_change_to_admin? && active?) || # admin is no longer admin
          (admin? && saved_change_to_status? && !active?)   # admin was locked
      deliver = true
      options[:message] = :mail_body_security_notification_remove
    end

    if deliver
      users = User.active.where(admin: true).to_a
      Mailer.deliver_security_notification(users, User.current, options)
    end
  end
end
