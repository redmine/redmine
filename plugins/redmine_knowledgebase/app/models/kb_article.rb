
# require Rails.version > '5.0' ? 'redmine/string_array_diff/diff' : 'diff'

# require_dependency 'redmine/helpers/diff'
class KbArticle < ApplicationRecord
  include Redmine::SafeAttributes

  self.locking_column = 'version'
  self.table_name = "kb_articles"

  validates_presence_of :title
  validates_presence_of :category_id

  belongs_to :project
  belongs_to :category, :class_name => "KbCategory"
  belongs_to :author,   :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :updater,  :class_name => 'User', :foreign_key => 'updater_id'

  up_acts_as_viewed
  acts_as_rated :no_rater => true
  up_acts_as_taggable
  acts_as_attachable
  acts_as_watchable

  acts_as_versioned :table_name => :kb_article_versions, :if_changed => [:title, :content, :summary]
  self.non_versioned_columns << 'comments_count'

  acts_as_event :title => Proc.new {|o| status = (o.new_status ? "(#{l(:label_new_article)})" : nil ); "#{status} #{l(:label_title_articles)} ##{o.id} - #{o.title}" },
                :description => :content,
                :datetime => :updated_at,
                :type => Proc.new { |o| 'article-' + (o.new_status ? 'add' : 'edit') },
                :url => Proc.new { |o| {:controller => 'articles', :action => 'show', :id => o.id, :project_id => o.project} }

  safe_attributes 'category_id',
                  'title',
                  'summary',
                  'content',
                  'author_id',
                  'comments_count',
                  'project_id',
                  'updater_id',
                  'version_comments',
                  'version',
                  'tag_list'


  # Redmine 3.1.X
  if ActiveRecord::VERSION::MAJOR >= 4
    acts_as_activity_provider :scope => joins(:project),
                              :permission => :view_kb_articles,
                              :author_key => :author_id,
                              :type => 'kb_articles',
                              :timestamp => :updated_at

    acts_as_searchable :columns => [ "#{table_name}.title", "#{table_name}.summary", "#{table_name}.content"],
                       :preload => [ :project ],
                       :date_column => :created_at

    scope :visible, lambda {|*args|
      joins(:project).
      where(Project.allowed_to_condition(args.shift || User.current, :view_kb_articles, *args))}
  else
    acts_as_activity_provider :find_options => {:include => :project},
                              :author_key => :author_id,
                              :type => 'kb_articles',
                              :timestamp => :updated_at

    acts_as_searchable :columns => [ "#{table_name}.title", "#{table_name}.summary", "#{table_name}.content"],
                       :include => [ :project ],
                       :order_column => "#{table_name}.id",
                       :date_column => "#{table_name}.created_at"

    scope :visible, lambda {|*args| { :include => :project,
      :conditions => Project.allowed_to_condition(args.shift || User.current, :view_kb_articles, *args) } }
  end

  has_many :comments, -> { order 'created_on DESC' }, :as => :commented, :dependent => :destroy


  def recipients
    notified = []
    # Author and assignee are always notified unless they have been
    # locked or don't want to be notified
    notified << author if author
    notified = notified.select {|u| u.active? && u.notify_about?(self)}
    notified.uniq!
    notified.collect(&:mail)
  end

  def editable_by?(user = User.current)
    return user.allowed_to?(:edit_articles, self.project) ||
      user.allowed_to?(:manage_articles, self.project) ||
      (user.allowed_to?(:manage_own_articles, self.project) && self.author_id == user.id)
  end

  def attachments_deletable?(user = User.current)
    editable_by?(user) || super(user)
  end

  def new_status
    if self.updater_id == 0
        true
    end
  end

  def content_for_version(version=nil)
    result = self.versions.find_by_version(version.to_i) if version
    result ||= self
    result
  end

  def diff(version_to=nil, version_from=nil)
    version_to = version_to ? version_to.to_i : self.version
    version_from = version_from ? version_from.to_i : version_to - 1
    version_to, version_from = version_from, version_to unless version_from < version_to

    content_to = self.versions.find_by_version(version_to)
    content_from = self.versions.find_by_version(version_from)

    (content_to && content_from) ? KbDiff.new(content_to, content_from) : nil
  end

  # Return true if the content is the current page content
  def current_version?
    true
  end

  #define the method to auto-remove new versions when reverting
  def clear_newer_versions
    excess_baggage = send(self.class.version_column).to_i
    if excess_baggage > 0
      sql = "DELETE FROM #{self.class.versioned_table_name} WHERE version > #{excess_baggage} AND #{self.class.versioned_foreign_key} = #{self.id}"
      self.class.versioned_class.connection.execute sql
    end
  end

  def self.count_article_summaries
    KbArticle.where("summary is not null and summary <> ''").count
  end

  class Version

    belongs_to :author,   :class_name => 'User', :foreign_key => 'author_id'
    belongs_to :updater,  :class_name => 'User', :foreign_key => 'updater_id'

    # Return true if the content is the current page content
    def current_version?
      KbArticle.version == self.version
    end

  end
end