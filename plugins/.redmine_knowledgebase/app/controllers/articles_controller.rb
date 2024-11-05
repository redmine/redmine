class ArticlesController < ApplicationController
  helper :attachments
  include AttachmentsHelper
  helper :knowledgebase
  include KnowledgebaseHelper
  helper :watchers
  include WatchersHelper

  before_action :find_project_by_project_id, :authorize
  before_action :get_article, :except => [:index, :new, :create, :preview, :comment, :tagged, :rate, :authored]
  before_action :find_attachments, :only => [:preview]

  rescue_from ActionView::MissingTemplate, :with => :force_404
  rescue_from ActiveRecord::RecordNotFound, :with => :force_404

  if ActiveRecord::ConnectionAdapters::Column.respond_to?(:type_cast_for_database)
    ActiveRecord::ConnectionAdapters::Column.send(:alias_method, :type_cast, :type_cast_for_database)
  end

  def index
    summary_limit = redmine_knowledgebase_settings_value(:summary_limit).to_i

    @total_categories = @project.categories.count
    @total_articles = @project.articles.count
    @total_articles_by_me = @project.articles.where(:author_id => User.current.id).count

    @categories = @project.categories.where(:parent_id => nil)

    @articles_newest = @project.articles.order("created_at DESC").first(summary_limit)
    @articles_latest = @project.articles.order("updated_at DESC").first(summary_limit)
    @articles_popular = @project.articles.includes(:viewings).sort_by(&:view_count).reverse.first(summary_limit)
    @articles_toprated = @project.articles.includes(:ratings).sort_by { |a| [a.rating_average, a.rated_count] }.reverse.first(summary_limit)

    @tags = @project.articles.tag_counts.sort { |a, b| a.name.downcase <=> b.name.downcase }
    @tags_hash = Hash[ @project.articles.tag_counts.map{ |tag| [tag.name.downcase, 1] } ]

  end

  def authored

    @author_id = params[:author_id]
    @articles = KbArticle.where('kb_articles.id in (?)', @project.articles.where(:author_id => @author_id).pluck(:id))
                         .order("#{KbArticle.table_name}.#{sort_column} #{sort_direction}")

    if params[:tag]
      @tag = params[:tag]
      @tag_array = *@tag.split(',')
      @tag_hash = Hash[ @tag_array.map{ |tag| [tag.downcase, 1] } ]
      @articles = KbArticle.where('kb_articles.id in (?)', @articles.tagged_with(@tag).map(&:id))
    end

    @tags = @articles.tag_counts.sort { |a, b| a.name.downcase <=> b.name.downcase }
    @tags_hash = Hash[ @articles.tag_counts.map{ |tag| [tag.name.downcase, 1] } ]

    # Pagination of article lists
    @limit = redmine_knowledgebase_settings_value( :articles_per_list_page).to_i
    @article_count = @articles.count
    @article_pages = Redmine::Pagination::Paginator.new @article_count, @limit, params['page']
    @offset ||= @article_pages.offset
    @articles = @articles.offset(@offset).limit(@limit)

    @categories = @project.categories.where(:parent_id => nil)
  end

  def new
    @article = KbArticle.new
    @categories = @project.categories.all
    @default_category = params[:category_id]
    @article.category_id = params[:category_id]
    @article.version = params[:version]

    # Prefill with critical tags
    if redmine_knowledgebase_settings_value(:critical_tags)
          @article.tag_list = redmine_knowledgebase_settings_value(:critical_tags).split(/\s*,\s*/)
    end

    @tags = @project.articles.tag_counts
  end

  def rate
    @article = KbArticle.find(params[:id])
    rating = params[:rating].to_i
    @article.rate rating if rating > 0

    respond_to do |f|
      f.js
    end
  end

  def create
    @article = KbArticle.new
    @article.safe_attributes = params[:article]
    @article.category_id = params[:category_id]
    @article.author_id = User.current.id
    @article.project_id = KbCategory.find(params[:category_id]).project_id
    @categories = @project.categories.all
    # don't keep previous comment
    @article.version_comments = params[:article][:version_comments]
    if @article.save
      attachments = attach(@article, params[:attachments])
      flash[:notice] = l(:label_article_created, :title => @article.title)
      redirect_to({ :action => 'show', :id => @article.id, :project_id => @project })
      KbMailer.article_create(User.current, @article).deliver
    else
      render(:action => 'new')
    end
  end

  def show
    @article.view request.remote_ip, User.current
    @attachments = @article.attachments.all.sort_by(&:created_on)
    @comments = @article.comments
    @versions = @article.versions.select("id, author_id, version_comments, updated_at, version").order('version DESC')
    @kb_use_thumbs = redmine_knowledgebase_settings_value(:show_thumbnails_for_articles)

    respond_to do |format|
      format.html { render :template => 'articles/show', :layout => !request.xhr? }
      format.atom { render_feed(@article, :title => "#{l(:label_article)}: #{@article.title}") }
	  format.pdf  { send_data(article_to_pdf(@article, @project), :type => 'application/pdf', :filename => 'export.pdf') }
    end
  end

  def edit
    if not @article.editable_by?(User.current)
      render_403
      return false
    end

    @categories=@project.categories.all

    # @page is used when using redmine_wysiwyg_editor plugin to show added attachments in menu
    @page = @article
    # don't keep previous comment
    @article.version_comments = nil
    @article.version = params[:version]
    @tags = @project.articles.tag_counts
    @kb_article_editing = true
    @kb_use_thumbs = redmine_knowledgebase_settings_value(:show_thumbnails_for_articles)
  end

  def update

    if not @article.editable_by?(User.current)
      render_403
      return false
    end

    @article.updater_id = User.current.id
    params[:article][:category_id] = params[:category_id]
    @categories = @project.categories.all
    # don't keep previous comment
    @article.version_comments = nil
    @article.version_comments = params[:article][:version_comments]
    @article.safe_attributes = params[:article]
    if @article.save
      attachments = attach(@article, params[:attachments])
      flash[:notice] = l(:label_article_updated)
      redirect_to({ :action => 'show', :id => @article.id, :project_id => @project })
      KbMailer.article_update(User.current, @article).deliver
    else
      render({:action => 'edit', :id => @article.id})
    end
  end

  def add_comment

    if params[:comment][:comments] == ""
      # Ignore empty comment
      show
    else

      @article.without_locking do
        @comment = Comment.new
        @comment.safe_attributes = params[:comment]
        @comment.author = User.current || nil
        if @article.comments << @comment
          flash[:notice] = l(:label_comment_added)
          redirect_to :action => 'show', :id => @article, :project_id => @project
          KbMailer.article_comment(User.current, @article, @comment).deliver
        else
          show
          render :action => 'show'
        end
      end
    end
  end

  def destroy_comment
    @article.without_locking do
      @article.comments.find(params[:comment_id]).destroy
      redirect_to :action => 'show', :id => @article, :project_id => @project
    end
  end

  def destroy

    if not @article.editable_by?(User.current)
      render_403
      return false
    end

    KbMailer.article_destroy(User.current, @article).deliver
    @article.destroy
    flash[:notice] = l(:label_article_removed)
    redirect_to({ :controller => 'articles', :action => 'index', :project_id => @project})
  end

  def add_attachment
    if not @article.editable_by?(User.current)
      render_403
      return false
    end

    attachments = attach(@article, params[:attachments])
    redirect_to({ :action => 'show', :id => @article.id, :project_id => @project })
  end

  def tagged
    @tag = params[:id]
    @list = if params[:sort] && params[:direction]
      @project.articles.order("#{params[:sort]} #{params[:direction]}").tagged_with(@tag)
    else
      @project.articles.tagged_with(@tag)
    end
  end

  def preview
    @article = @project.articles.find_by(id: params[:id])

    # page is nil when previewing a new page
    return render_403 unless @article.nil? || @article.editable_by?(User.current)

    if @article
      @attachments += @article.attachments
      @previewed = @article
    end
    @text = params[:article].present? ? params[:article][:text] : params[:text]
    render :partial => 'common/preview'
  end

  def comment
    @article_id = params[:article_id]

    respond_to do |f|
      f.js
    end
  end

  def version
    @articleversion = @article.content_for_version(params[:version])
  end

  def diff
    @diff = @article.diff(params[:version], params[:version_from])
    render_404 unless @diff
    @articleversion = @article.content_for_version(params[:version])
  end

  def revert
    @article.revert_to! params[:version]
    @article.clear_newer_versions
    redirect_to :action => 'show', :id => @article, :project_id => @project
  end
#######
private
#######

  # Abstract attachment method to resolve how files should be attached to a model.
  # In newer versions of Redmine, the attach_files functionality was moved
  # from the application controller to the attachment model.
  def attach(target, attachments)
    if Attachment.respond_to?(:attach_files)
      Attachment.attach_files(target, attachments)
      render_attachment_warning_if_needed(target)
    else
      attach_files(target, attachments)
    end
  end

  def get_article
    @article = @project.articles.find(params[:id])
  end

  def force_404
    render_404
  end

end
