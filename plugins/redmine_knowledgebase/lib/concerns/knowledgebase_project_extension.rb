module KnowledgebaseProjectExtension
  extend ActiveSupport::Concern
  included do
    has_many :categories, :class_name => "KbCategory", :foreign_key => "project_id"
    has_many :articles, :class_name => "KbArticle", :foreign_key => "project_id"
  end
end
