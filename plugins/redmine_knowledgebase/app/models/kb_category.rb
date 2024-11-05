class KbCategory < ApplicationRecord
  include Redmine::SafeAttributes

  self.table_name = "kb_categories"

  validates_presence_of :title

  belongs_to :project
  has_many :articles, :class_name => "KbArticle", :foreign_key => "category_id"

  acts_as_nested_set :order => 'title'
  acts_as_watchable

  safe_attributes 'title',
                  'description',
                  'parent_id',
                  'project_id'

end
