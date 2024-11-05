module KnowledgebaseLinkHelper

  def link_to_article(article)
    link_to l(:label_kb_link, :kb_id => article.id.to_s), article_path(article.project, article.id), :title => article.title
  end

  def link_to_article_with_title(article)
    link_to "#{l(:label_kb_link, :kb_id => article.id.to_s)}: #{article.title}", article_path(article.project, article.id)
  end

  def link_to_category_with_title(category)
    link_to category.title, category_path(category.project, category.id)
  end

end
