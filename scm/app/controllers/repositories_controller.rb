class RepositoriesController < ApplicationController
  layout 'base'
  before_filter :find_project

  def show
  end
  
  def browse
    @rev = params[:rev].to_i if params[:rev] and params[:rev].to_i > 0
    @entry = @repository.scm.entry(@path, @rev)
    redirect_to :action => 'show', :id => @project and return unless @entry
    if @entry.is_dir?
      # if entry is a dir, shows directory listing
      @entries = @repository.scm.entries(@path, @rev)
      redirect_to :action => 'show', :id => @project and return unless @entries
    else
      # else, shows file's revisions
      @revisions = @repository.scm.revisions(@path, @rev)
      redirect_to :action => 'show', :id => @project and return unless @revisions
      render :action => 'entry_revisions'
    end
  end
  
  def revision
    @rev = params[:rev].to_i if params[:rev] and params[:rev].to_i > 0
    @revisions = @repository.scm.revisions '', @rev, @rev, :with_paths => true
    redirect_to :action => 'show', :id => @project and return unless @revisions
    @revision = @revisions.first  
  end
  
  def diff
    @rev = params[:rev].to_i if params[:rev] and params[:rev].to_i > 0
    @rev_to = params[:rev_to] || (@rev-1)
    @diff = @repository.scm.diff(params[:path], @rev, @rev_to)
    redirect_to :action => 'show', :id => @project and return unless @diff
  end
  
private
  def find_project
    @project = Project.find(params[:id])
    @repository = @project.repository
    @path = params[:path].squeeze('/').gsub(/^\//, '') if params[:path]
  end
end
