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

class ScmFetchError < StandardError; end

class Repository < ApplicationRecord
  include Redmine::Ciphering
  include Redmine::SafeAttributes

  # Maximum length for repository identifiers
  IDENTIFIER_MAX_LENGTH = 255

  belongs_to :project
  has_many :changesets, lambda{order("#{Changeset.table_name}.committed_on DESC, #{Changeset.table_name}.id DESC")}
  has_many :filechanges, :class_name => 'Change', :through => :changesets

  serialize :extra_info

  before_validation :normalize_identifier
  before_save :check_default

  # Raw SQL to delete changesets and changes in the database
  # has_many :changesets, :dependent => :destroy is too slow for big repositories
  before_destroy :clear_changesets

  validates_length_of :login, maximum: 60, allow_nil: true
  validates_length_of :password, :maximum => 255, :allow_nil => true
  validates_length_of :root_url, :url, maximum: 255
  validates_length_of :identifier, :maximum => IDENTIFIER_MAX_LENGTH, :allow_blank => true
  validates_uniqueness_of :identifier, :scope => :project_id, :case_sensitive => true
  validates_exclusion_of :identifier, :in => %w(browse show entry raw changes annotate diff statistics graph revisions revision)
  # donwcase letters, digits, dashes, underscores but not digits only
  validates_format_of :identifier, :with => /\A(?!\d+$)[a-z0-9\-_]*\z/, :allow_blank => true
  # Checks if the SCM is enabled when creating a repository
  validate :repo_create_validation, :on => :create
  validate :validate_repository_path

  safe_attributes(
    'identifier',
    'login',
    'password',
    'path_encoding',
    'log_encoding',
    'is_default')

  safe_attributes(
    'url',
    :if => lambda {|repository, user| repository.new_record?})

  def repo_create_validation
    unless Setting.enabled_scm.include?(self.class.name.demodulize)
      errors.add(:type, :invalid)
    end
  end

  def self.human_attribute_name(attribute_key_name, *args)
    attr_name = attribute_key_name.to_s
    if attr_name == "log_encoding"
      attr_name = "commit_logs_encoding"
    end
    super(attr_name, *args)
  end

  # Removes leading and trailing whitespace
  def url=(arg)
    write_attribute(:url, arg ? arg.to_s.strip : nil)
  end

  # Removes leading and trailing whitespace
  def root_url=(arg)
    write_attribute(:root_url, arg ? arg.to_s.strip : nil)
  end

  def password
    read_ciphered_attribute(:password)
  end

  def password=(arg)
    write_ciphered_attribute(:password, arg)
  end

  def scm_adapter
    self.class.scm_adapter_class
  end

  def scm
    unless @scm
      @scm = self.scm_adapter.new(url, root_url,
                                  login, password, path_encoding)
      if root_url.blank? && @scm.root_url.present?
        update_attribute(:root_url, @scm.root_url)
      end
    end
    @scm
  end

  def scm_name
    self.class.scm_name
  end

  def name
    if identifier.present?
      identifier
    elsif is_default?
      l(:field_repository_is_default)
    else
      scm_name
    end
  end

  def identifier=(identifier)
    super unless identifier_frozen?
  end

  def identifier_frozen?
    errors[:identifier].blank? && !(new_record? || identifier.blank?)
  end

  def identifier_param
    if identifier.present?
      identifier
    else
      id.to_s
    end
  end

  def <=>(repository)
    return nil unless repository.is_a?(Repository)

    if is_default?
      -1
    elsif repository.is_default?
      1
    else
      identifier.to_s <=> repository.identifier.to_s
    end
  end

  def self.find_by_identifier_param(param)
    if /^\d+$/.match?(param.to_s)
      find_by_id(param)
    else
      find_by_identifier(param)
    end
  end

  # TODO: should return an empty hash instead of nil to avoid many ||{}
  def extra_info
    h = read_attribute(:extra_info)
    h.is_a?(Hash) ? h : nil
  end

  def merge_extra_info(arg)
    h = extra_info || {}
    return h if arg.nil?

    h.merge!(arg)
    write_attribute(:extra_info, h)
  end

  def report_last_commit
    true
  end

  def supports_cat?
    scm.supports_cat?
  end

  def supports_annotate?
    scm.supports_annotate?
  end

  def supports_history?
    true
  end

  def supports_directory_revisions?
    false
  end

  def supports_revision_graph?
    false
  end

  def entry(path=nil, identifier=nil)
    scm.entry(path, identifier)
  end

  def scm_entries(path=nil, identifier=nil)
    scm.entries(path, identifier)
  end
  protected :scm_entries

  def entries(path=nil, identifier=nil)
    entries = scm_entries(path, identifier)
    load_entries_changesets(entries)
    entries
  end

  def branches
    scm.branches
  end

  def tags
    scm.tags
  end

  def default_branch
    nil
  end

  def properties(path, identifier=nil)
    scm.properties(path, identifier)
  end

  def cat(path, identifier=nil)
    scm.cat(path, identifier)
  end

  def diff(path, rev, rev_to)
    scm.diff(path, rev, rev_to)
  end

  def diff_format_revisions(cs, cs_to, sep=':')
    text = ""
    text += cs_to.format_identifier + sep if cs_to
    text += cs.format_identifier if cs
    text
  end

  # Returns a path relative to the url of the repository
  def relative_path(path)
    path
  end

  # Finds and returns a revision with a number or the beginning of a hash
  def find_changeset_by_name(name)
    return nil if name.blank?

    s = name.to_s
    if /^\d*$/.match?(s)
      changesets.find_by(:revision => s)
    else
      changesets.where("revision LIKE ?", s + '%').first
    end
  end

  def latest_changeset
    @latest_changeset ||= changesets.first
  end

  # Returns the latest changesets for +path+
  # Default behaviour is to search in cached changesets
  def latest_changesets(path, rev, limit=10)
    if path.blank?
      changesets.
        reorder("#{Changeset.table_name}.committed_on DESC, #{Changeset.table_name}.id DESC").
        limit(limit).
        preload(:user).
        to_a
    else
      filechanges.
        where("path = ?", path.with_leading_slash).
        reorder("#{Changeset.table_name}.committed_on DESC, #{Changeset.table_name}.id DESC").
        limit(limit).
        preload(:changeset => :user).
        collect(&:changeset)
    end
  end

  def scan_changesets_for_issue_ids
    self.changesets.each(&:scan_comment_for_issue_ids)
  end

  # Returns an array of committers usernames and associated user_id
  def committers
    @committers ||= Changeset.where(:repository_id => id).distinct.pluck(:committer, :user_id)
  end

  # Maps committers username to a user ids
  def committer_ids=(h)
    if h.is_a?(Hash)
      committers.each do |committer, user_id|
        new_user_id = h[committer]
        if new_user_id && (new_user_id.to_i != user_id.to_i)
          new_user_id = (new_user_id.to_i > 0 ? new_user_id.to_i : nil)
          Changeset.where(["repository_id = ? AND committer = ?", id, committer]).
            update_all("user_id = #{new_user_id.nil? ? 'NULL' : new_user_id}")
        end
      end
      @committers            = nil
      @found_committer_users = nil
      true
    else
      false
    end
  end

  # Returns the Redmine User corresponding to the given +committer+
  # It will return nil if the committer is not yet mapped and if no User
  # with the same username or email was found
  def find_committer_user(committer)
    unless committer.blank?
      @found_committer_users ||= {}
      return @found_committer_users[committer] if @found_committer_users.has_key?(committer)

      user = nil
      c = changesets.where(:committer => committer).
            includes(:user).references(:user).first
      if c && c.user
        user = c.user
      elsif committer.strip =~ /^([^<]+)(<(.*)>)?$/
        username, email = $1.strip, $3
        u = User.find_by_login(username)
        u ||= User.find_by_mail(email) unless email.blank?
        user = u
      end
      @found_committer_users[committer] = user
      user
    end
  end

  def repo_log_encoding
    encoding = log_encoding.to_s.strip
    encoding.blank? ? 'UTF-8' : encoding
  end

  # Fetches new changesets for all repositories of active projects
  # Can be called periodically by an external script
  # eg. ruby script/runner "Repository.fetch_changesets"
  def self.fetch_changesets
    Project.active.has_module(:repository).all.each do |project|
      project.repositories.each do |repository|
        begin
          repository.fetch_changesets
        rescue Redmine::Scm::Adapters::CommandFailed => e
          logger.error "scm: error during fetching changesets: #{e.message}"
        end
      end
    end
  end

  # scan changeset comments to find related and fixed issues for all repositories
  def self.scan_changesets_for_issue_ids
    all.each(&:scan_changesets_for_issue_ids)
  end

  def self.scm_name
    'Abstract'
  end

  def self.available_scm
    subclasses.collect {|klass| [klass.scm_name, klass.name]}
  end

  def self.factory(klass_name, *args)
    repository_class(klass_name).new(*args) rescue nil
  end

  def self.repository_class(class_name)
    class_name = class_name.to_s.camelize
    if Redmine::Scm::Base.all.include?(class_name)
      "Repository::#{class_name}".constantize
    end
  end

  def self.scm_adapter_class
    nil
  end

  def self.scm_command
    ret = ""
    begin
      ret = self.scm_adapter_class.client_command if self.scm_adapter_class
    rescue => e
      logger.error "scm: error during get command: #{e.message}"
    end
    ret
  end

  def self.scm_version_string
    ret = ""
    begin
      ret = self.scm_adapter_class.client_version_string if self.scm_adapter_class
    rescue => e
      logger.error "scm: error during get version string: #{e.message}"
    end
    ret
  end

  def self.scm_available
    ret = false
    begin
      ret = self.scm_adapter_class.client_available if self.scm_adapter_class
    rescue => e
      logger.error "scm: error during get scm available: #{e.message}"
    end
    ret
  end

  def set_as_default?
    new_record? && project && Repository.where(:project_id => project.id).empty?
  end

  # Returns a hash with statistics by author in the following form:
  # {
  #   "John Smith" => { :commits => 45, :changes => 324 },
  #   "Bob" => { ... }
  # }
  #
  # Notes:
  # - this hash honnors the users mapping defined for the repository
  def stats_by_author
    commits = Changeset.where("repository_id = ?", id).
                select("committer, user_id, count(*) as count").group("committer, user_id")
    # TODO: restore ordering ; this line probably never worked
    # commits.to_a.sort! {|x, y| x.last <=> y.last}
    changes = Change.joins(:changeset).where("#{Changeset.table_name}.repository_id = ?", id).
                select("committer, user_id, count(*) as count").group("committer, user_id")
    user_ids = changesets.filter_map(&:user_id).uniq
    authors_names = User.where(:id => user_ids).inject({}) do |memo, user|
      memo[user.id] = user.to_s
      memo
    end
    (commits + changes).inject({}) do |hash, element|
      mapped_name = element.committer
      if username = authors_names[element.user_id.to_i]
        mapped_name = username
      end
      hash[mapped_name] ||= {:commits_count => 0, :changes_count => 0}
      if element.is_a?(Changeset)
        hash[mapped_name][:commits_count] += element.count.to_i
      else
        hash[mapped_name][:changes_count] += element.count.to_i
      end
      hash
    end
  end

  # Returns a scope of changesets that come from the same commit as the given changeset
  # in different repositories that point to the same backend
  def same_commits_in_scope(scope, changeset)
    scope = scope.joins(:repository).where(:repositories => {:url => url, :root_url => root_url, :type => type})
    if changeset.scmid.present?
      scope = scope.where(:scmid => changeset.scmid)
    else
      scope = scope.where(:revision => changeset.revision)
    end
    scope
  end

  def valid_name?(name)
    scm.valid_name?(name)
  end

  protected

  # Validates repository url based against an optional regular expression
  # that can be set in the Redmine configuration file.
  def validate_repository_path(attribute=:url)
    regexp = Redmine::Configuration["scm_#{scm_name.to_s.downcase}_path_regexp"]
    if changes[attribute] && regexp.present?
      regexp = regexp.to_s.strip.gsub('%project%') {Regexp.escape(project.try(:identifier).to_s)}
      unless Regexp.new("\\A#{regexp}\\z").match?(send(attribute).to_s)
        errors.add(attribute, :invalid)
      end
    end
  end

  def normalize_identifier
    self.identifier = identifier.to_s.strip
  end

  def check_default
    if !is_default? && set_as_default?
      self.is_default = true
    end
    if is_default? && is_default_changed?
      Repository.where(["project_id = ?", project_id]).update_all(["is_default = ?", false])
    end
  end

  def load_entries_changesets(entries)
    if entries
      entries.each do |entry|
        if entry.lastrev && entry.lastrev.identifier
          entry.changeset = find_changeset_by_name(entry.lastrev.identifier)
        end
      end
    end
  end

  private

  # Deletes repository data
  def clear_changesets
    cs = Changeset.table_name
    ch = Change.table_name
    ci = "#{table_name_prefix}changesets_issues#{table_name_suffix}"
    cp = "#{table_name_prefix}changeset_parents#{table_name_suffix}"

    self.class.connection.delete("DELETE FROM #{ch} WHERE #{ch}.changeset_id IN (SELECT #{cs}.id FROM #{cs} WHERE #{cs}.repository_id = #{id})")
    self.class.connection.delete("DELETE FROM #{ci} WHERE #{ci}.changeset_id IN (SELECT #{cs}.id FROM #{cs} WHERE #{cs}.repository_id = #{id})")
    self.class.connection.delete("DELETE FROM #{cp} WHERE #{cp}.changeset_id IN (SELECT #{cs}.id FROM #{cs} WHERE #{cs}.repository_id = #{id})")
    self.class.connection.delete("DELETE FROM #{cs} WHERE #{cs}.repository_id = #{id}")
  end
end
