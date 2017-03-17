class GithubProjectController < ApplicationController
  unloadable

  before_filter :find_project, :authorize

  def index
    if @github_project.present?
      redirect_to :action => :show, id: @github_project.id, project_id: @project.id
    else
      redirect_to action: :new, project_id: @project.id
    end
  end

  def show
  end

  def new
    @github_project = GithubProject.new()
  end

  def edit
  end

  def create
    @github_project = GithubProject.new(params[:github_relation])
    @github_project.project_id = @project.id

    unless @github_project.save
      render :action => :new
      return
    end
    redirect_to :action => :show, id: @github_project.id, project_id: @project.id
  end

  def update
    @github_project.attributes = params[:github_relation]
    @github_project.project_id = @project.id

    unless @github_project.save
      render :action => :edit
      return
    end
    redirect_to :action => :show, id: @github_project.id, project_id: @project.id
  end

  def get_data
    @github_project.get_from_github(params[:login], params[:password])
    redirect_to :action => :show, id: @github_project.id, project_id: @project.id
  end

  private
  def find_project
    @project = Project.find(params[:project_id])
    @github_project = GithubProject.where(project_id: @project.id).first
  end

end
