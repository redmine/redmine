# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class Changeset < ActiveRecord::Base
  belongs_to :repository
  belongs_to :user
  has_many :filechanges, :class_name => 'Change', :dependent => :delete_all
  has_and_belongs_to_many :issues
  has_and_belongs_to_many :parents,
                          :class_name => "Changeset",
                          :join_table => "#{table_name_prefix}changeset_parents#{table_name_suffix}",
                          :association_foreign_key => 'parent_id', :foreign_key => 'changeset_id'
  has_and_belongs_to_many :children,
                          :class_name => "Changeset",
                          :join_table => "#{table_name_prefix}changeset_parents#{table_name_suffix}",
                          :association_foreign_key => 'changeset_id', :foreign_key => 'parent_id'

  acts_as_event :title => Proc.new {|o| o.title},
                :description => :long_comments,
                :datetime => :committed_on,
                :url => Proc.new {|o| {:controller => 'repositories', :action => 'revision', :id => o.repository.project, :repository_id => o.repository.identifier_param, :rev => o.identifier}}

  acts_as_searchable :columns => 'comments',
                     :preload => {:repository => :project},
                     :project_key => "#{Repository.table_name}.project_id",
                     :date_column => :committed_on

  acts_as_activity_provider :timestamp => "#{table_name}.committed_on",
                            :author_key => :user_id,
                            :scope => preload(:user, {:repository => :project})

  validates_presence_of :repository_id, :revision, :committed_on, :commit_date
  validates_uniqueness_of :revision, :scope => :repository_id
  validates_uniqueness_of :scmid, :scope => :repository_id, :allow_nil => true
  attr_protected :id

  scope :visible, lambda {|*args|
    joins(:repository => :project).
    where(Project.allowed_to_condition(args.shift || User.current, :view_changesets, *args))
  }

  after_create :scan_for_issues
  before_create :before_create_cs

  def revision=(r)
    write_attribute :revision, (r.nil? ? nil : r.to_s)
  end

  # Returns the identifier of this changeset; depending on repository backends
  def identifier
    if repository.class.respond_to? :changeset_identifier
      repository.class.changeset_identifier self
    else
      revision.to_s
    end
  end

  def committed_on=(date)
    self.commit_date = date
    super
  end

  # Returns the readable identifier
  def format_identifier
    if repository.class.respond_to? :format_changeset_identifier
      repository.class.format_changeset_identifier self
    else
      identifier
    end
  end

  def project
    repository.project
  end

  def author
    user || committer.to_s.split('<').first
  end

  def before_create_cs
    self.committer = self.class.to_utf8(self.committer, repository.repo_log_encoding)
    self.comments  = self.class.normalize_comments(
                       self.comments, repository.repo_log_encoding)
    self.user = repository.find_committer_user(self.committer)
  end

  def scan_for_issues
    scan_comment_for_issue_ids
  end

  TIMELOG_RE = /
    (
    ((\d+)(h|hours?))((\d+)(m|min)?)?
    |
    ((\d+)(h|hours?|m|min))
    |
    (\d+):(\d+)
    |
    (\d+([\.,]\d+)?)h?
    )
    /x

  def scan_comment_for_issue_ids
    return if comments.blank?
    # keywords used to reference issues
    ref_keywords = Setting.commit_ref_keywords.downcase.split(",").collect(&:strip)
    ref_keywords_any = ref_keywords.delete('*')
    # keywords used to fix issues
    fix_keywords = Setting.commit_update_keywords_array.map {|r| r['keywords']}.flatten.compact

    kw_regexp = (ref_keywords + fix_keywords).collect{|kw| Regexp.escape(kw)}.join("|")

    referenced_issues = []

    comments.scan(/([\s\(\[,-]|^)((#{kw_regexp})[\s:]+)?(#\d+(\s+@#{TIMELOG_RE})?([\s,;&]+#\d+(\s+@#{TIMELOG_RE})?)*)(?=[[:punct:]]|\s|<|$)/i) do |match|
      action, refs = match[2].to_s.downcase, match[3]
      next unless action.present? || ref_keywords_any

      refs.scan(/#(\d+)(\s+@#{TIMELOG_RE})?/).each do |m|
        issue, hours = find_referenced_issue_by_id(m[0].to_i), m[2]
        if issue && !issue_linked_to_same_commit?(issue)
          referenced_issues << issue
          # Don't update issues or log time when importing old commits
          unless repository.created_on && committed_on && committed_on < repository.created_on
            fix_issue(issue, action) if fix_keywords.include?(action)
            log_time(issue, hours) if hours && Setting.commit_logtime_enabled?
          end
        end
      end
    end

    referenced_issues.uniq!
    self.issues = referenced_issues unless referenced_issues.empty?
  end

  def short_comments
    @short_comments || split_comments.first
  end

  def long_comments
    @long_comments || split_comments.last
  end

  def text_tag(ref_project=nil)
    repo = ""
    if repository && repository.identifier.present?
      repo = "#{repository.identifier}|"
    end
    tag = if scmid?
      "commit:#{repo}#{scmid}"
    else
      "#{repo}r#{revision}"
    end
    if ref_project && project && ref_project != project
      tag = "#{project.identifier}:#{tag}"
    end
    tag
  end

  # Returns the title used for the changeset in the activity/search results
  def title
    repo = (repository && repository.identifier.present?) ? " (#{repository.identifier})" : ''
    comm = short_comments.blank? ? '' : (': ' + short_comments)
    "#{l(:label_revision)} #{format_identifier}#{repo}#{comm}"
  end

  # Returns the previous changeset
  def previous
    @previous ||= Changeset.where(["id < ? AND repository_id = ?", id, repository_id]).order('id DESC').first
  end

  # Returns the next changeset
  def next
    @next ||= Changeset.where(["id > ? AND repository_id = ?", id, repository_id]).order('id ASC').first
  end

  # Creates a new Change from it's common parameters
  def create_change(change)
    Change.create(:changeset     => self,
                  :action        => change[:action],
                  :path          => change[:path],
                  :from_path     => change[:from_path],
                  :from_revision => change[:from_revision])
  end

  # Finds an issue that can be referenced by the commit message
  def find_referenced_issue_by_id(id)
    return nil if id.blank?
    issue = Issue.find_by_id(id.to_i)
    if Setting.commit_cross_project_ref?
      # all issues can be referenced/fixed
    elsif issue
      # issue that belong to the repository project, a subproject or a parent project only
      unless issue.project &&
                (project == issue.project || project.is_ancestor_of?(issue.project) ||
                 project.is_descendant_of?(issue.project))
        issue = nil
      end
    end
    issue
  end

  private

  # Returns true if the issue is already linked to the same commit
  # from a different repository
  def issue_linked_to_same_commit?(issue)
    repository.same_commits_in_scope(issue.changesets, self).any?
  end

  # Updates the +issue+ according to +action+
  def fix_issue(issue, action)
    # the issue may have been updated by the closure of another one (eg. duplicate)
    issue.reload
    # don't change the status is the issue is closed
    return if issue.closed?

    journal = issue.init_journal(user || User.anonymous,
                                 ll(Setting.default_language,
                                    :text_status_changed_by_changeset,
                                    text_tag(issue.project)))
    rule = Setting.commit_update_keywords_array.detect do |rule|
      rule['keywords'].include?(action) &&
        (rule['if_tracker_id'].blank? || rule['if_tracker_id'] == issue.tracker_id.to_s)
    end
    if rule
      issue.assign_attributes rule.slice(*Issue.attribute_names)
    end
    Redmine::Hook.call_hook(:model_changeset_scan_commit_for_issue_ids_pre_issue_update,
                            { :changeset => self, :issue => issue, :action => action })

    if issue.changes.any?
      unless issue.save
        logger.warn("Issue ##{issue.id} could not be saved by changeset #{id}: #{issue.errors.full_messages}") if logger
      end
    end
    issue
  end

  def log_time(issue, hours)
    time_entry = TimeEntry.new(
      :user => user,
      :hours => hours,
      :issue => issue,
      :spent_on => commit_date,
      :comments => l(:text_time_logged_by_changeset, :value => text_tag(issue.project),
                     :locale => Setting.default_language)
      )
    time_entry.activity = log_time_activity unless log_time_activity.nil?

    unless time_entry.save
      logger.warn("TimeEntry could not be created by changeset #{id}: #{time_entry.errors.full_messages}") if logger
    end
    time_entry
  end

  def log_time_activity
    if Setting.commit_logtime_activity_id.to_i > 0
      TimeEntryActivity.find_by_id(Setting.commit_logtime_activity_id.to_i)
    end
  end

  def split_comments
    comments =~ /\A(.+?)\r?\n(.*)$/m
    @short_comments = $1 || comments
    @long_comments = $2.to_s.strip
    return @short_comments, @long_comments
  end

  public

  # Strips and reencodes a commit log before insertion into the database
  def self.normalize_comments(str, encoding)
    Changeset.to_utf8(str.to_s.strip, encoding)
  end

  def self.to_utf8(str, encoding)
    Redmine::CodesetUtil.to_utf8(str, encoding)
  end
end
