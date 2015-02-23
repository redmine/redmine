# Redmine - project management software
# Copyright (C) 2006-2014  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'securerandom'

class ProjectsController < ApplicationController
  menu_item :overview
  menu_item :roadmap, :only => :roadmap
  menu_item :settings, :only => :settings

  before_filter :find_project, :except => [ :index, :list, :new, :create, :copy, :cells_graph, :cells_list, :cells_gallery, :cells_tags, :technology, :groups, :people, :informationOSB, :generateGEPPETTOSimulationFile]
  before_filter :authorize, :except => [ :index, :list, :new, :create, :copy, :archive, :unarchive, :destroy, :cells_graph, :cells_list, :cells_gallery, :cells_tags, :technology, :groups, :people, :informationOSB, :addTag, :removeTag, :generateGEPPETTOSimulationFile]
  before_filter :authorize_global, :only => [:new, :create]
  before_filter :require_admin, :only => [ :copy, :archive, :unarchive, :destroy ]
  accept_rss_auth :index
  accept_api_auth :index, :show, :create, :update, :destroy
    
  after_filter :only => [:create, :edit, :update, :archive, :unarchive, :destroy] do |controller|
    if controller.request.post?
      controller.send :expire_action, :controller => 'welcome', :action => 'robots'
    end
  end

  helper :sort
  include SortHelper
  helper :custom_fields
  include CustomFieldsHelper
  helper :issues
  helper :queries
  include QueriesHelper
  helper :repositories
  include RepositoriesHelper
  include ProjectsHelper
  include ApplicationHelper
  helper :members

  # Load projects base page....
  def index
    respond_to do |format|
      format.api  {
        @offset, @limit = api_offset_and_limit
        @project_count = Project.visible.count
        @projects = Project.visible.offset(@offset).limit(@limit).order('lft').all
      }
      format.html {
      }
      format.atom {
        projects = Project.visible.order('created_on DESC').limit(Setting.feeds_limit.to_i).all
        render_feed(projects, :title => "#{Setting.app_title}: #{l(:label_project_latest)}")
      }
    end
  end

  def cells_graph
      respond_to do |format|
        format.html {
          scope = Project
          unless params[:closed]
            scope = scope.active
          end
          @projects = scope.visible.order('lft').all
        }
      end

      render :layout => false
  end
  
  def cells_list
    respond_to do |format|
      format.html {
        scope = Project
        unless params[:closed]
          scope = scope.active
        end
        @projects = scope.visible.order('lft').all
      }
    end
    
    @modelProjects = []
    for p in @projects
      if isEndorsedOrBestPractice?(p)
        category=getCustomField(p,'Category')
        if category=='Project'
          @modelProjects.push(p)
        end
      end
    end
    
    render :layout => false
  end
  
  def cells_gallery
    respond_to do |format|
      format.html {
        scope = Project
        unless params[:closed]
          scope = scope.active
        end
        @projects = scope.visible.order('lft').all
      }
    end

    @galleryImages = []
    for p in @projects
      if isEndorsedOrBestPractice?(p)
        projectDescription = p.description
        firstLine = projectDescription.lines.first.chomp
        #This is for textile
        #if (firstLine.start_with?("!") and firstLine.end_with?("!"))
        #This is for markdown
        if (firstLine.start_with?("![]"))
          @galleryImages.push({:image => firstLine, :project => p})
        end
      end
    end
    
    render :layout => false
  end  
    
  def cells_tags
    respond_to do |format|
      format.html {
        scope = Project
        unless params[:closed]
          scope = scope.active
        end
        @projects = scope.visible.order('lft').all
      }
    end

    @tagsDict = Hash.new  
    for p in @projects
      if isEndorsedOrBestPractice?(p)
       
        tags=getCustomField(p,'Tags')
        unless tags.nil?
          for tag in tags.split(",")
            ocurrences = 1
            if @tagsDict.has_key?(tag)
              ocurrences = @tagsDict[tag] + 1
            end
            @tagsDict[tag]=ocurrences
          end
        end  
      end
    end
    
    render :layout => false
  end 
  
  # Lists visible projects
#  def cells
#    time1 = Time.now
#    
#    respond_to do |format|
#      format.html {
#        scope = Project
#        unless params[:closed]
#          scope = scope.active
#        end
#        @projects = scope.visible.order('lft').all
#      }
#    end
#
#    @modelProjects = []
##    @showcaseProjects = []
#    @galleryImages = []
#    @tagsDict = Hash.new  
#    for p in @projects
#      if isEndorsed?(p)
#        projectDescription = p.description
#        firstLine = projectDescription.lines.first.chomp
#        #This is for textile
#        #if (firstLine.start_with?("!") and firstLine.end_with?("!"))
#        #This is for markdown
#        if (firstLine.start_with?("![]"))
#          @galleryImages.push({:image => firstLine, :project => p})
#        end
#        category=getCustomField(p,'Category')
#        if category=='Project'
#          @modelProjects.push(p)
##        elsif category=='Showcase'
##          @showcaseProjects.push(p)
#        end
#        
#        tags=getCustomField(p,'Tags')
#        unless tags.nil?
#          for tag in tags.split(",")
#            ocurrences = 1
#            if @tagsDict.has_key?(tag)
#              ocurrences = @tagsDict[tag] + 1
#            end
#            @tagsDict[tag]=ocurrences
#          end
#        end  
#      end
#    end
#    
#    time2 = Time.now
#    render :layout => false
#    time3 = Time.now
#    
#    dif1 = (time2 - time1) * 1000
#    dif2 = (time3 - time2) * 1000
#    
#    open("#{Rails.root}/config/times.yml", 'a') { |f|
#      f.puts time1
#      f.puts time2
#      f.puts time3
#      f.puts dif1
#      f.puts dif2
#    }
#  end

  # Lists groups
  def groups
    @groups = Group.find(:all, :order => 'lastname')
    render :layout => false
  end

  # Lists people
  def people
    userscope = User.logged.status(@status)
    userscope = userscope.like(params[:name]) if params[:name].present?
    userscope = userscope.in_group(params[:group_id]) if params[:group_id].present?
    @users = userscope.find(:all, :order => 'lastname')
    render :layout => false
  end

  # Lists showcase projects in technology tabs
  def technology
    respond_to do |format|
      format.html {
        scope = Project
        unless params[:closed]
          scope = scope.active
        end
        @projects = scope.visible.order('lft').all
      }
      format.api  {
        @offset, @limit = api_offset_and_limit
        @project_count = Project.visible.count
        @projects = Project.visible.offset(@offset).limit(@limit).order('lft').all
      }
      format.atom {
        projects = Project.visible.order('created_on DESC').limit(Setting.feeds_limit.to_i).all
        render_feed(projects, :title => "#{Setting.app_title}: #{l(:label_project_latest)}")
      }
    end

    @showcaseProjects=[]
    for p in @projects
      if isEndorsedOrBestPractice?(p)
        category=getCustomField(p,'Category')
        if category=='Showcase'
          @showcaseProjects.push(p)
        end
      end
    end

    render :layout => false
  end

  # Lists projects in information OSB tab
  def informationOSB
    respond_to do |format|
      format.html {
        scope = Project
        unless params[:closed]
          scope = scope.active
        end
        @projects = scope.visible.order('lft').all
      }
      format.api  {
        @offset, @limit = api_offset_and_limit
        @project_count = Project.visible.count
        @projects = Project.visible.offset(@offset).limit(@limit).order('lft').all
      }
      format.atom {
        projects = Project.visible.order('created_on DESC').limit(Setting.feeds_limit.to_i).all
        render_feed(projects, :title => "#{Setting.app_title}: #{l(:label_project_latest)}")
      }
    end

    render :layout => false
  end

  def new
    @issue_custom_fields = IssueCustomField.sorted.all
    @trackers = Tracker.sorted.all
    @project = Project.new
    @project.safe_attributes = params[:project]
  end

  def adminnew
    @issue_custom_fields = IssueCustomField.sorted.all
    @trackers = Tracker.sorted.all
    @project = Project.new
    @project.safe_attributes = params[:project]
  end

  def validateGitHubRepo(repository)

    if repository!=""
      #checks is valid
      #check is already cloned?
      gitFolder=File.basename(repository)
      if gitFolder!=""
        if not File.directory? "/home/svnsvn/myGitRepositories/"+gitFolder
          if File.extname(gitFolder)==".git" and (repository.starts_with?"http")
            #exit_code = system("git ls-remote "+repository + " &> /dev/null")
            if url_exists(repository[0..-5])
              return true
            else
              @project.errors.add " ", "Can not connect to repository. Check url format (we are expecting something like https://github.com/user/myProject.git) and connectivity."
            end
          else
            @project.errors.add " ", "The specified URL is not a valid Git repository. We are expecting something like https://github.com/user/myProject.git"
          end
        else
          @project.errors.add " ", "The Git repository specified is already referenced by some other project."
        end
      else
        @project.errors.add " ", "You need to specify a Git repository."
      end
    else
      return true
    end
    return false
  end

  def mirrorGitHubRepo(repository)
    mirroredRepo="/home/svnsvn/myGitRepositories/"+File.basename(repository)
    exec("git clone --mirror "+repository+" "+mirroredRepo)
    return mirroredRepo
  end

  def addMirroredRepo(repo)
    attrs = getRepoAttrs(repo)
    @repository = Repository.factory('Git')
    @repository.safe_attributes = attrs[:attrs]
    if attrs[:attrs_extra].keys.any?
      @repository.merge_extra_info(attrs[:attrs_extra])
    end
    @project.save
    @repository.project = @project
    @repository.save
  end

  def getRepoAttrs(repo)
    p       = {}
    p_extra = {}
    p_extra['extra_report_last_commit'] = 1
    p['is_default'] = 1
    p['identifier'] = ''
    p['url'] = repo
    p['path_encoding'] = ''
    {:attrs => p, :attrs_extra => p_extra}
  end

  def create
    @issue_custom_fields = IssueCustomField.sorted.all
    @trackers = Tracker.sorted.all
    @project = Project.new
    @project.safe_attributes = params[:project]
    @githubRepo=getCustomField(@project,'GitHub repository')

    if validate_parent_id && validateGitHubRepo(@githubRepo) && @project.save
      @project.set_allowed_parent!(params[:project]['parent_id']) if params[:project].has_key?('parent_id')
      # Add current user as a project member if current user is not admin
      unless User.current.admin?
        r = Role.givable.find_by_id(Setting.new_project_user_role_id.to_i) || Role.givable.first
        m = Member.new(:user => User.current, :roles => [r])
        @project.members << m
      end
      respond_to do |format|
        format.html {
          flash[:success] = l(:notice_successful_create)
          if params[:continue]
            attrs = {:parent_id => @project.parent_id}.reject {|k,v| v.nil?}
            redirect_to new_project_path(attrs)
          else
            redirect_to settings_project_path(@project)
          end
        }
        format.api  { render :action => 'show', :status => :created, :location => url_for(:controller => 'projects', :action => 'show', :id => @project.id) }
      end

      if @githubRepo!=""
        @mirroredRepo=mirrorGitHubRepo(@githubRepo)
        addMirroredRepo(@mirroredRepo)
      end

    else
      respond_to do |format|
        format.html { render :action => 'new' }
        format.api  { render_validation_errors(@project) }
      end
    end
  end

  def copy
    @issue_custom_fields = IssueCustomField.sorted.all
    @trackers = Tracker.sorted.all
    @source_project = Project.find(params[:id])
    if request.get?
      @project = Project.copy_from(@source_project)
      @project.identifier = Project.next_identifier if Setting.sequential_project_identifiers?
    else
      Mailer.with_deliveries(params[:notifications] == '1') do
        @project = Project.new
        @project.safe_attributes = params[:project]
        if validate_parent_id && @project.copy(@source_project, :only => params[:only])
          @project.set_allowed_parent!(params[:project]['parent_id']) if params[:project].has_key?('parent_id')
          flash[:success] = l(:notice_successful_create)
          redirect_to settings_project_path(@project)
        elsif !@project.new_record?
          # Project was created
          # But some objects were not copied due to validation failures
          # (eg. issues from disabled trackers)
          # TODO: inform about that
          redirect_to settings_project_path(@project)
        end
      end
    end
  rescue ActiveRecord::RecordNotFound
    # source_project not found
    render_404
  end

  # Show @project
  def show
    # try to redirect to the requested menu item
    if params[:jump] && redirect_to_project_menu_item(@project, params[:jump])
      return
    end
    
#    if params[:explorer]
#      url = params[:explorer]
#      uri = URI.parse(url)
#      idName = File.basename(uri.path).split(".").first
#
#      neuromlTemplate = File.read("#{Rails.root}/public/geppetto/neuromlTemplate.xml")
#      neuromlTemplate.sub! '$ENTER_MODEL_URL', url
##      neuromlTemplate.sub! '$ENTER_ID', idName
#      neuromlTemplate.sub! '$ENTER_ID', 'idName'
#      neuromlTemplate.sub! '$ENTER_SCRIPT_URL', 'http://127.0.0.1:3000/geppetto/geppettoScript.js'
#        
#      random_string = SecureRandom.hex
#      @geppettoSimulationFile = "/geppetto/tmp/" + random_string + ".xml"; 
#      File.write("#{Rails.root}/public"+ @geppettoSimulationFile, neuromlTemplate)
#    end  

    @users_by_role = @project.users_by_role
    @subprojects = @project.children.visible.all
    @news = @project.news.limit(5).includes(:author, :project).reorder("#{News.table_name}.created_on DESC").all
    @trackers = @project.rolled_up_trackers

    cond = @project.project_condition(Setting.display_subprojects_issues?)

    @open_issues_by_tracker = Issue.visible.open.where(cond).group(:tracker).count
    @total_issues_by_tracker = Issue.visible.where(cond).group(:tracker).count

    if User.current.allowed_to?(:view_time_entries, @project)
      @total_hours = TimeEntry.visible.where(cond).sum(:hours).to_f
    end

    @key = User.current.rss_key

    respond_to do |format|
      format.html
      format.api
    end
  end
  
  def generateGEPPETTOSimulationFile
      url = params[:explorer]
      uri = URI.parse(url)

      publicResourcesPath = "#{Rails.root}/public/"
      geppettoResourcesPath = "geppetto/";
      geppettoTmpPath = "geppetto/tmp/"
      simulationTemplates = "simulationTemplates/"
      scripts = "scripts/"
      if session[:geppettoIP].nil? || session[:geppettoIP].empty? || session[:geppettoIP] =="" 
        props = YAML::load(File.open("#{Rails.root}/config/props.yml"))
        session[:serverIP] = props["serverIP"]
        session[:geppettoIP] = props["geppettoIP"]
      end
      serverIP = session[:serverIP];
          
      filenameSplit = File.basename(uri.path).split(".")
      entity = filenameSplit[0]
      #FIXME: This a quick fix but actually we should check entity is valid js variable name
      if /^\d+/.match(entity) 
        entity = "e" + entity
      end  
      docType = filenameSplit[1]
            
      geppettoSimulationFile = File.read(publicResourcesPath + geppettoResourcesPath + simulationTemplates + "neuromlTemplate.xml")
#      geppettoSimulationFile = File.read(publicResourcesPath + geppettoResourcesPath + simulationTemplates + "lemsTemplate.xml")
      if docType == 'net'
        geppettoJsFile = File.read(publicResourcesPath + geppettoResourcesPath + scripts + "osbNetworkScript.js")
      elsif docType == 'channel'
        geppettoJsFile = File.read(publicResourcesPath + geppettoResourcesPath + scripts + "osbChannelScript.js")
      elsif docType == 'synapse'
        geppettoJsFile = File.read(publicResourcesPath + geppettoResourcesPath + scripts + "osbSynapseScript.js")
      elsif docType == 'cell'
        geppettoJsFile = File.read(publicResourcesPath + geppettoResourcesPath + scripts + "osbCellScript.js")
      else
        geppettoJsFile = File.read(publicResourcesPath + geppettoResourcesPath + scripts + "osbGenericScript.js")  
      end

      # Generate simulation and js file path
      geppettoTmpSimulationFile = Tempfile.new([entity,".xml"], publicResourcesPath + geppettoTmpPath);
      @geppettoSimulationFilePath = File.basename(geppettoTmpSimulationFile.path)
      geppettoTmpJsFile = Tempfile.new([entity,".js"], publicResourcesPath + geppettoTmpPath);
      @geppettoJsFilePath = File.basename(geppettoTmpJsFile.path)
         
      # Parse simulation file      
      geppettoSimulationFile.sub! '$ENTER_MODEL_URL', url
      geppettoSimulationFile.sub! '$ENTER_ID', entity

      geppettoSimulationFile.sub! '$ENTER_SCRIPT_URL', serverIP + geppettoTmpPath + @geppettoJsFilePath
      #geppettoSimulationFile.sub! '$ENTER_SCRIPT_URL', 'http://127.0.0.1:3000/' + geppettoTmpPath + @geppettoJsFilePath
      #geppettoSimulationFile.sub! '$ENTER_SCRIPT_URL', 'http://comodl.org/' + geppettoTmpPath + @geppettoJsFilePath
      #geppettoSimulationFile.sub! '$ENTER_SCRIPT_URL', 'http://opensourcebrain.org/' + geppettoTmpPath + @geppettoJsFilePath
        
      # Parse js file
      geppettoJsFile.gsub! '$ENTER_ID', entity
      
#      begin
        # Write files to tmp folder
        File.write(publicResourcesPath + geppettoTmpPath + @geppettoSimulationFilePath, geppettoSimulationFile)
        File.write(publicResourcesPath + geppettoTmpPath + @geppettoJsFilePath, geppettoJsFile)
#      ensure
#        geppettoTmpSimulationFile.close
#        geppettoTmpSimulationFile.unlink
#        geppettoTmpJsFile.close
#        geppettoTmpJsFile.unlink
#      end   
        
        
      geppettoSimulationFileObj = {"geppettoSimulationFile"=> geppettoTmpPath + @geppettoSimulationFilePath}
      render json: geppettoSimulationFileObj
  end  

  def settings
    @issue_custom_fields = IssueCustomField.sorted.all
    @issue_category ||= IssueCategory.new
    @member ||= @project.members.new
    @trackers = Tracker.sorted.all
    @wiki ||= @project.wiki
  end

  def edit
  end
  
  def addTag
    tag = params[:tag]
    @project.custom_field_values.each do |value|
      if value.custom_field.name == 'Tags'
        tagsContent = (value.value == nil || value.value == '')?tag:value.value + "," + tag
        @project.safe_attributes =  {"name"=> @project.name, "description" => @project.description, "identifier"=>@project.to_param, "custom_field_values" => {value.custom_field.id.to_s => tagsContent}}
        if validate_parent_id && @project.save
          #render :nothing => true, :status => 200, :content_type => 'text/html'
          #render :layout => false
          tagsContentFile = YAML::load(File.open("#{Rails.root}/config/tags.yml"))
          
          ocurrences = 1
          if tagsContentFile != false && tagsContentFile != '' 
            if tagsContentFile.has_key?(tag)
              ocurrences = tagsContentFile[tag] + 1
            end  
          else
            tagsContentFile = {}
          end  
          tagsContentFile[tag] = ocurrences
          
          File.open("#{Rails.root}/config/tags.yml",'w') do |h| 
             h.write tagsContentFile.to_yaml
          end
          
          tags=getCustomField(@project,'Tags')
          roles = User.current.roles_for_project(@project).collect(&:name) 
          render :partial=>'tags', :locals=>{:tags=>tags, :roles=>roles}
        end
      end
    end

  end
  
  def removeTag
    tag = params[:tag]
    @project.custom_field_values.each do |value|
      if value.custom_field.name == 'Tags'
        
        tagsContentSplit = value.value.dup.split(",")
        tagsContentSplit.delete(tag)
        tagsContent = tagsContentSplit.join(",")
        
        @project.safe_attributes =  {"name"=> @project.name, "description" => @project.description, "identifier"=>@project.to_param, "custom_field_values" => {value.custom_field.id.to_s => tagsContent}}
        if validate_parent_id && @project.save
          tagsContentFile = YAML::load(File.open("#{Rails.root}/config/tags.yml"))
          
          ocurrences = 0
          if tagsContentFile != false && tagsContentFile != '' && tagsContentFile.has_key?(tag)
            ocurrences = tagsContentFile[tag] - 1
          else
            tagsContentFile = {}
          end  

          if ocurrences == 0
            tagsContentFile.delete(tag)
          else
            tagsContentFile[tag] = ocurrences
          end  
            
          File.open("#{Rails.root}/config/tags.yml",'w') do |h| 
             h.write tagsContentFile.to_yaml
          end
          
          tags=getCustomField(@project,'Tags')
          
          roles = User.current.roles_for_project(@project).collect(&:name) 
          render :partial=>'tags', :locals=>{:tags=>tags, :roles=>roles}
        end
      end
    end  
  end  

  def update
    @project.safe_attributes = params[:project]
    if validate_parent_id && @project.save
      @project.set_allowed_parent!(params[:project]['parent_id']) if params[:project].has_key?('parent_id')
      respond_to do |format|
        format.html {
          flash[:success] = l(:notice_successful_update)
          redirect_to settings_project_path(@project)
        }
        format.api  { render_api_ok }
      end
    else
      respond_to do |format|
        format.html {
          settings
          render :action => 'settings'
        }
        format.api  { render_validation_errors(@project) }
      end
    end
  end

  def modules
    @project.enabled_module_names = params[:enabled_module_names]
    flash[:success] = l(:notice_successful_update)
    redirect_to settings_project_path(@project, :tab => 'modules')
  end

  def archive
    if request.post?
      unless @project.archive
        flash[:error] = l(:error_can_not_archive_project)
      end
    end
    redirect_to admin_projects_path(:status => params[:status])
  end

  def unarchive
    @project.unarchive if request.post? && !@project.active?
    redirect_to admin_projects_path(:status => params[:status])
  end

  def close
    @project.close
    redirect_to project_path(@project)
  end

  def reopen
    @project.reopen
    redirect_to project_path(@project)
  end

  # Delete @project
  def destroy
    @project_to_destroy = @project
    if api_request? || params[:confirm]
      @project_to_destroy.destroy
      respond_to do |format|
        format.html { redirect_to admin_projects_path }
        format.api  { render_api_ok }
      end
    end
    # hide project in layout
    @project = nil
  end

  private

  # Validates parent_id param according to user's permissions
  # TODO: move it to Project model in a validation that depends on User.current
  def validate_parent_id
    return true if User.current.admin?
    parent_id = params[:project] && params[:project][:parent_id]
    if parent_id || @project.new_record?
      parent = parent_id.blank? ? nil : Project.find_by_id(parent_id.to_i)
      unless @project.allowed_parents.include?(parent)
        @project.errors.add :parent_id, :invalid
        return false
      end
    end
    true
  end

end
