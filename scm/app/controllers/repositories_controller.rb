class RepositoriesController < ApplicationController
  layout 'base'
  before_filter :find_project

  def show
  end
  
  def browse
    @entries = @repository.scm.entries(@path, @rev)
    redirect_to :action => 'show', :id => @project and return unless @entries
  end
  
  def entry_revisions
    @entry = @repository.scm.entry(@path, @rev)
    @revisions = @repository.scm.revisions(@path, @rev)
    redirect_to :action => 'show', :id => @project and return unless @entry && @revisions
  end
  
  def entry
    if 'raw' == params[:format]
      content = @repository.scm.cat(@path, @rev)
      redirect_to :action => 'show', :id => @project and return unless content
      send_data content, :filename => @path.split('/').last
    end
  end
  
  def revision
    @revisions = @repository.scm.revisions '', @rev, @rev, :with_paths => true
    redirect_to :action => 'show', :id => @project and return unless @revisions
    @revision = @revisions.first  
  end
  
  def diff
    @rev_to = params[:rev_to] || (@rev-1)
    @diff = @repository.scm.diff(params[:path], @rev, @rev_to)
    redirect_to :action => 'show', :id => @project and return unless @diff
  end
  
private
  def find_project
    @project = Project.find(params[:id])
    @repository = @project.repository
    @path = params[:path].squeeze('/').gsub(/^\//, '') if params[:path]
    @path ||= ''
    @rev = params[:rev].to_i if params[:rev] and params[:rev].to_i > 0
  end
end
