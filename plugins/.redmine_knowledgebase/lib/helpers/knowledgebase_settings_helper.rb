module KnowledgebaseSettingsHelper
  def redmine_knowledgebase_settings_value(key)
    defaults = Redmine::Plugin::registered_plugins[:redmine_knowledgebase].settings[:default]

    value = begin 
      Setting['plugin_redmine_knowledgebase'][key]
    rescue
      nil
    end

    value.blank? ? defaults[key] : value
  end
  
  def redmine_knowledgebase_count_article_summaries
    "#{KbArticle.count_article_summaries} of #{KbArticle.count} have summaries"
  end
end