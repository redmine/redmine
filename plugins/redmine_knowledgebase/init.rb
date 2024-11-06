require 'redmine'

if (Rails.configuration.respond_to?(:autoloader) && Rails.configuration.autoloader == :zeitwerk) || Rails.version > '7.0'
  Rails.autoloaders.each { |loader| loader.ignore(File.dirname(__FILE__) + '/lib') }
end
require File.dirname(__FILE__) + '/lib/redmine_knowledgebase'

Project.send :include, KnowledgebaseProjectExtension
SettingsHelper.send :include, KnowledgebaseSettingsHelper
ApplicationHelper.send :include, Redmineup::TagsHelper

Redmine::Activity.register :kb_articles
Redmine::Search.register :kb_articles

Redmine::Plugin.register :redmine_knowledgebase do
  name        'Knowledgebase'
  author      'Alex Bevilacqua'
  author_url  "http://www.alexbevi.com"
  description 'A plugin for Redmine that adds knowledgebase functionality'
  url         'https://github.com/alexbevi/redmine_knowledgebase'
  version     '5.0.0'

  requires_redmine :version_or_higher => '4.0.0'

  # Do not set any default boolean settings to true or will override user false setting!
  settings :default => {
    :summary_limit => 25,
    :articles_per_list_page => 100,
    :disable_article_summaries => false
  }, :partial => 'redmine_knowledgebase/knowledgebase_settings'

  project_module :knowledgebase do
    permission :view_kb_articles, {
      :articles      => [:index, :show, :tagged, :authored],
      :categories    => [:index, :show]
    }
    permission :comment_and_rate_articles, {
      :articles      => [:index, :show, :tagged, :rate, :comment, :add_comment],
      :categories    => [:index, :show]
    }
    permission :create_articles, {
      :articles      => [:index, :show, :tagged, :new, :create, :add_attachment, :preview],
      :categories    => [:index, :show]
    }
    permission :edit_articles, {
      :articles      => [:index, :show, :tagged, :edit, :update, :add_attachment, :preview],
      :categories    => [:index, :show]
    }
    permission :manage_articles, {
      :articles      => [:index, :show, :new, :create, :edit, :update, :destroy, :add_attachment,
                         :preview, :comment, :add_comment, :destroy_comment, :tagged],
      :categories    => [:index, :show]
    }
    permission :manage_own_articles, {
      :articles      => [:index, :show, :edit, :update, :destroy, :add_attachment, :preview, :tagged],
      :categories    => [:index, :show]
    }
    permission :manage_articles_comments, {
      :articles      => [:index, :show, :comment, :add_comment, :destroy_comment],
      :categories    => [:index, :show]
    }
    permission :create_article_categories, {
      :articles      => :index,
      :categories    => [:index, :show, :new, :create]
    }
    permission :manage_article_categories, {
      :articles      => :index,
      :categories    => [:index, :show, :new, :create, :edit, :update, :destroy]
    }
    permission :watch_articles, {
      :watchers		=> [:new, :destroy]
    }
    permission :watch_categories, {
      :watchers => [:new, :destroy]
    }
    permission :view_recent_articles, {
      :articles => :index
    }
    permission :view_most_popular_articles, {
      :articles => :index
    }
    permission :view_top_rated_articles, {
      :articles => :index
    }
    permission :view_article_history, {
      :articles => [:diff, :version]
    }
    permission :manage_article_history, {
      :articles => [:diff, :version, :revert]
    }
  end

  menu :project_menu, :articles, { :controller => 'articles', :action => 'index' }, :caption => :knowledgebase_title, :after => :activity, :param => :project_id

end

class RedmineKnowledgebaseHookListener < Redmine::Hook::ViewListener
  render_on :view_layouts_base_html_head, :inline => "<%= stylesheet_link_tag 'knowledgebase', :plugin => :redmine_knowledgebase %>"
end
