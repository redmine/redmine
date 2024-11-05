class CategoriesController < ApplicationController
  menu_item :articles
  helper :knowledgebase
  include KnowledgebaseHelper
  helper :watchers
  include WatchersHelper

  before_action :find_project_by_project_id, :authorize
  before_action :get_category, :only => [:show, :edit, :update, :destroy, :index]
  Rails.version > '5.0' ? accept_atom_auth(:show) : accept_rss_auth(:show)

  rescue_from ActiveRecord::RecordNotFound, :with => :force_404

  def index

    @articles = @project.articles.order("#{sort_column} #{sort_direction}")

    prepare

    respond_to do |format|
      format.html { render :template => 'categories/index', :layout => !request.xhr? }
    end

  end

  def show

    @articles = @category.articles.order("#{sort_column} #{sort_direction}")

    prepare

    @tags = @articles.tag_counts.sort { |a, b| a.name.downcase <=> b.name.downcase }

    respond_to do |format|
      format.html { render :template => 'categories/show', :layout => !request.xhr? }
      format.atom { render_feed(@articles, :title => "#{l(:knowledgebase_title)}: #{l(:label_category)}: #{@category.title}") }
    end

  end

  def new
    @category = KbCategory.new
    @parent_id = params[:parent_id]
    @categories=@project.categories.all
  end

  def create
    @category = KbCategory.new
    @category.safe_attributes = params[:category]
    @category.project_id=@project.id
    if @category.save
      # Test if the new category is a root category, and if more categories exist.
      # We check for a value > 1 because if this is the first entry, the category
      # count would be 1 (since the create operation already succeeded)
      if !params[:root_category] and @project.categories.count > 1
        @category.move_to_child_of(KbCategory.find(params[:parent_id]))
      end

      flash[:notice] = l(:label_category_created, :title => @category.title)
      redirect_to({ :action => 'show', :id => @category.id, :project_id => @project })
    else
      render(:action => 'new')
    end
  end

  def edit
    @parent_id = @category.parent_id
    @categories=@project.categories.all
  end

  def destroy
    @categories = @project.categories.all

    # Do not allow deletion of categories with existing subcategories
    @subcategories = @project.categories.where(:parent_id => @category.id)

    if @subcategories.size != 0
      @articles = @category.articles.all
      flash[:error] = l(:label_category_has_subcategory_cannot_delete)
      render(:action => 'show')
    elsif @category.articles.size != 0
      @articles = @category.articles.all
      flash[:error] = l(:label_category_not_empty_cannot_delete)
      render(:action => 'show')
    else
      @category.destroy
      flash[:notice] = l(:label_category_deleted)
      redirect_to({ :controller => :articles, :action => 'index', :project_id => @project})
    end
  end

  def update
    if params[:root_category] == "yes"
      @category.parent_id = nil
    else
      @category.move_to_child_of(KbCategory.find(params[:parent_id]))
    end

    @category.safe_attributes = params[:category]
    if @category.save
      flash[:notice] = l(:label_category_updated)
      redirect_to({ :action => 'show', :id => @category.id, :project_id => @project })
    else
      render :action => 'edit'
    end
  end

#######
private
#######

  def get_category
    if params[:id] != nil
      @category = @project.categories.find(params[:id])
    end
  end

  def force_404
    render_404
  end

  def prepare

    if params[:tag]
      @tag = params[:tag]
      @tag_array = *@tag.split(',')
      @tag_hash = Hash[ @tag_array.map{ |tag| [tag.downcase, 1] } ]
      @articles = KbArticle.where(id: @articles.tagged_with(@tag).map(&:id))
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

end
