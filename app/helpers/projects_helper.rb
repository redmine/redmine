# encoding: utf-8
#
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

require 'open-uri'
require 'yaml'

module ProjectsHelper
  include ThemesHelper
  include GuidesHelper
  
  def link_to_version(version, options = {})
    return '' unless version && version.is_a?(Version)
    link_to_if version.visible?, format_version_name(version), { :controller => 'versions', :action => 'show', :id => version }, options
  end

  def project_settings_tabs
    tabs = [{:name => 'info', :action => :edit_project, :partial => 'projects/edit', :label => :label_information_plural},
            {:name => 'modules', :action => :select_project_modules, :partial => 'projects/settings/modules', :label => :label_module_plural},
            {:name => 'members', :action => :manage_members, :partial => 'projects/settings/members', :label => :label_member_plural},
            {:name => 'versions', :action => :manage_versions, :partial => 'projects/settings/versions', :label => :label_version_plural},
            {:name => 'categories', :action => :manage_categories, :partial => 'projects/settings/issue_categories', :label => :label_issue_category_plural},
            {:name => 'wiki', :action => :manage_wiki, :partial => 'projects/settings/wiki', :label => :label_wiki},
            {:name => 'repositories', :action => :manage_repository, :partial => 'projects/settings/repositories', :label => :label_repository_plural},
            {:name => 'boards', :action => :manage_boards, :partial => 'projects/settings/boards', :label => :label_board_plural},
            {:name => 'activities', :action => :manage_project_activities, :partial => 'projects/settings/activities', :label => :enumeration_activities}
            ]
    tabs.select {|tab| User.current.allowed_to?(tab[:action], @project)}
  end

  def parent_project_select_tag(project)
    selected = project.parent
    # retrieve the requested parent project
    parent_id = (params[:project] && params[:project][:parent_id]) || params[:parent_id]
    if parent_id
      selected = (parent_id.blank? ? nil : Project.find(parent_id))
    end

    options = ''
    options << "<option value=''>&nbsp;</option>" if project.allowed_parents.include?(nil)
    options << project_tree_options_for_select(project.allowed_parents.compact, :selected => selected)
    content_tag('select', options.html_safe, :name => 'project[parent_id]', :id => 'project_parent_id')
  end

  def render_project_action_links
    links = []
    links << link_to(l(:label_project_new), {:controller => 'projects', :action => 'new'}, :class => 'icon icon-add') if User.current.allowed_to?(:add_project, nil, :global => true)
    links << link_to(l(:label_issue_view_all), issues_path) if User.current.allowed_to?(:view_issues, nil, :global => true)
    links << link_to(l(:label_overall_spent_time), time_entries_path) if User.current.allowed_to?(:view_time_entries, nil, :global => true)
    links << link_to(l(:label_overall_activity), { :controller => 'activities', :action => 'index', :id => nil })
    links.join(" | ").html_safe
  end

  # Renders the projects index
  def render_project_hierarchy(projects)
    render_project_nested_lists(projects) do |project|
      s = link_to_project(project, {}, :class => "#{project.css_classes} #{User.current.member_of?(project) ? 'my-project' : nil}")
      if project.description.present?
        s << content_tag('div', textilizable(project.short_description, :project => project), :class => 'wiki description')
      end
      s
    end
  end
  
  def getAvailableTags()
    tagsContent = YAML::load(File.open("#{Rails.root}/config/tags.yml"))
    if tagsContent != false
      tagsContent = tagsContent.keys.sort {|a, b| tagsContent[b] <=> tagsContent[a]}
        
      projectsTags = getCustomField(@project, 'Tags')
      if projectsTags!=nil and projectsTags!='' and projectsTags!=[nil] 
          tagsContent = tagsContent - projectsTags.split(",")   
      end  
      return tagsContent
    end
    return ''
  end  
 
  #MC - probably there's a more elegant way to do this, not a Ruby expert
  def addNode(t,c1,c2,c3,c4,c5,dname,link,category)
    if category == 'Project'
      if(c1!=nil and c2!=nil and c3!=nil and c4!=nil and c5!=nil and dname!=nil and link!=nil)
        if(!t.has_key?(c1))
          t[c1]= Hash.new()
        end
        if(!t[c1].has_key?(c2))
          t[c1][c2]= Hash.new()
        end
        if(!t[c1][c2].has_key?(c3))
          t[c1][c2][c3]=Hash.new()
        end
        if(!t[c1][c2][c3].has_key?(c4))
          t[c1][c2][c3][c4]=Hash.new()
        end
        if(!t[c1][c2][c3][c4].has_key?(c5))
          t[c1][c2][c3][c4][c5]=Hash.new()
        end
        if(!t[c1][c2][c3][c4][c5].has_key?(dname))
          t[c1][c2][c3][c4][c5][dname]=link
        end
      end
    end
  end

  def createJSONProjectTree(projects)
    t = Hash.new()
    if projects.any?
      projects.each do |project|
        c1=c2=c3=c4=c5=dname=category=nil
        if isEndorsedOrBestPractice?(project)
          project.visible_custom_field_values.each do |custom_value|
            if (custom_value.custom_field.name == 'Category')
              category=custom_value.value
            elsif (custom_value.custom_field.name == 'Spine classification')
              c1=custom_value.value
            elsif (custom_value.custom_field.name == 'Family')
              c2=custom_value.value
            elsif (custom_value.custom_field.name == 'Brain region')
              c4=custom_value.value
            elsif (custom_value.custom_field.name == 'Specie')
              c3=custom_value.value
            elsif (custom_value.custom_field.name == 'Cell type')
              c5=custom_value.value
            end
          end
        end
        addNode(t,c1,c2,c3,c4,c5,project.name,"/projects/"+project.identifier,category)
      end
      return jsonify(t).to_json
    end
  end

  def jsonify(t)
    newt = Hash.new()
    newt["name"]="Animal Kingdom"
    newt["children"]= Array.new()
    t.each_pair do |k,v|
      newt["children"] << jsonifynode(k,v)
    end
    return newt
  end

  def jsonifynode(name, node)
    newt = Hash.new()
    newt["name"]=name
    if(node.kind_of?(Hash))
      newt["children"]= Array.new()
      node.each_pair do |k,v|
        newt["children"] << jsonifynode(k,v)
      end
    elsif
    newt["link"]=node
    end
    return newt
  end

  # Renders a tree of projects as a nested set of unordered lists
  # The given collection may be a subset of the whole project tree
  # (eg. some intermediate nodes are private and can not be seen)
  def render_project_hierarchy(projects, category)
    s = ''
    if projects.any?
      ancestors = []
      original_project = @project

      #display first Vertebrate...
      mapp=Hash.new()
      projects.each do |p|
        p.visible_custom_field_values.each do |custom_value|
          if (custom_value.custom_field.name == 'Spine classification')
            if (!custom_value.value.nil?())
              if(!mapp.has_key?(custom_value.value))
                mapp[custom_value.value]=Array.new()
              end
              mapp[custom_value.value] << p
            end
          end
        end
      end
      #by gathering all categories as keys and list of projects as values and sorting in reverse order the keys
      mapp.keys().sort().reverse().each do |key|
        mapp[key].each do |project|

          show_this = 0

          project.visible_custom_field_values.each do |custom_value|
            if (custom_value.custom_field.name == 'Category')
              if (custom_value.value == category)
                show_this = 1
              end
            end
          end

          if (show_this == 1)
            # set the project environment to please macros.
            @project = project
            if (ancestors.empty? || project.is_descendant_of?(ancestors.last))
              s << "<ul class='projects #{ ancestors.empty? ? 'root' : nil}'>\n"
            else
              ancestors.pop
              s << "</li>"
              while (ancestors.any? && !project.is_descendant_of?(ancestors.last))
                ancestors.pop
                s << "</ul></li>\n"
              end
            end
            classes = (ancestors.empty? ? 'root' : 'child')
            s << "<li class='#{classes}'><div class='#{classes}'>" +
            link_to_project(project, {}, :class => "project #{User.current.member_of?(project) ? 'my-project' : nil}")
            s << "<div class='wiki description'>#{textilizable(project.short_description, :project => project)}</div>" unless project.description.blank?
            s << "</div>\n"
            ancestors << project
          end
        end
      end
      @project = nil
      s << "</ul>"
      s.html_safe
    end
  end

  # Returns a set of options for a select field, grouped by project.
  def version_options_for_select(versions, selected=nil)
    grouped = Hash.new {|h,k| h[k] = []}
    versions.each do |version|
      grouped[version.project.name] << [version.name, version.id]
    end

    selected = selected.is_a?(Version) ? selected.id : selected
    if grouped.keys.size > 1
      grouped_options_for_select(grouped, selected)
    else
      options_for_select((grouped.values.first || []), selected)
    end
  end

  def format_version_sharing(sharing)
    sharing = 'none' unless Version::VERSION_SHARINGS.include?(sharing)
    l("label_version_sharing_#{sharing}")
  end
  
  def file_age(name)
    (Time.now - File.ctime(name))
  end
  
  def generateGEPPETTOSimulationFileFromUrl(url, max_age = 600)
    uri = URI.parse(url)
      
      ##############################
      # CREATE ENTITY AND DOC TYPE #
      ##############################
      #Read entity name and model type (cell,channel,synapse,cell) from url  
      filename = File.basename(uri.path)
      filenameSplit = filename.split(".")

      # Get entity id, format (swc or nml) and if nml the doc type (net, cell, channel, synapse or other)
      # Remove anything but numbers and letters and add an 'e' at the beginning in case it starts with a number
      entity = filenameSplit[0]
      # entity.tr!('^A-Za-z0-9', '')
      entity.tr!("[&\\/\\\\#,+()$~%.'\":*?<>{}\s]", '_')
      if /^\d+/.match(entity)
        entity = "id" + entity
      end 
      
      if filenameSplit[-1] == 'swc'
        format = 'swc'
      else  
        format = 'nml'
        docType = filenameSplit[-2]
      end
      
      ########
      # PATH #
      ########
      publicResourcesPath = "#{Rails.root}/public/"
      geppettoResourcesPath = "geppetto/";
      geppettoTmpPath = "geppetto/tmp/"
      simulationTemplates = "simulationTemplates/"
      scripts = "scripts/"
      
       # Delete old files (older than max age (seconds))
      Dir[publicResourcesPath + geppettoTmpPath + "*"].each do |filename| 
        if file_age(filename) >  max_age
          File.delete(filename) 
        end  
      end 
      
      # Generate simulation and js file path
      random_string = SecureRandom.hex
      geppettoTmpSimulationFile = File.new(publicResourcesPath + geppettoTmpPath + entity + random_string + ".json", File::CREAT|File::TRUNC|File::RDWR, 0644)
      @geppettoSimulationFilePath = File.basename(geppettoTmpSimulationFile.path)
      geppettoTmpModelFile = File.new(publicResourcesPath + geppettoTmpPath + entity + "_MODEL" + random_string + ".xmi", File::CREAT|File::TRUNC|File::RDWR, 0644)
      @geppettoModelFilePath = File.basename(geppettoTmpModelFile.path)
      if format == 'nml'
        geppettoTmpJsFile = File.new(publicResourcesPath + geppettoTmpPath + entity + random_string + ".js", File::CREAT|File::TRUNC|File::RDWR, 0644)
        @geppettoJsFilePath = File.basename(geppettoTmpJsFile.path)
        
        ######################
        # JS & CONTROL PANEL #
        ######################
        if docType == 'net'
            geppettoJsFile = File.read(publicResourcesPath + geppettoResourcesPath + scripts + "osbNetworkScript.js")
        elsif docType == 'cell'
            geppettoJsFile = File.read(publicResourcesPath + geppettoResourcesPath + scripts + "osbCellScript.js")
        elsif docType == 'channel' 
          geppettoJsFile = File.read(publicResourcesPath + geppettoResourcesPath + scripts + "osbChannelScript.js")
        elsif docType == 'synapse'
          geppettoJsFile = File.read(publicResourcesPath + geppettoResourcesPath + scripts + "osbSynapseScript.js")
        else
          geppettoJsFile = File.read(publicResourcesPath + geppettoResourcesPath + scripts + "osbGenericScript.js")  
        end
         
        geppettoJsFile.gsub! '$ENTER_ID', entity
        geppettoJsFile.gsub!(/\s*\/\/.*/, '')
        geppettoJsFile.gsub!(/\/\*!.*?\*\//m, '')
        geppettoJsFile.delete!("\r\n")
      end  
      
      ##############
      # SIMULATION #
      ##############
      retries = 4
      begin
        modelContent = open(url, 'r', :read_timeout=>2)
      rescue OpenURI::HTTPError
        if (retries -= 1) > 0
          print "Error requesting modelContent. Model can't be found at #{url}"
          retry
        else
           geppettoSimulationFileObj = {"error" => "Model at #{url} does not exist or is not reachable at the moment"}
          return geppettoSimulationFileObj
        end  
      rescue => e   
         print "Error requesting modelContent: #{url}"
      else
        if format == 'nml'
          if (docType == 'net' || docType == 'cell')
            target=""
            
            if docType == 'net'
              targetComponent = /<network id="(\w*)\"/.match(modelContent.read)
            elsif 
              targetComponent = /<cell id="(\w*)\"/.match(modelContent.read)
            end
            
            if targetComponent
              target = targetComponent.captures
            end

            geppettoSimulationFile = {
              "id" => 1,
              "name" => target[0],
              "activeExperimentId" => 1,
              "experiments" => [{
                                  "id" => 1,
                                  "name" => filenameSplit[0]+ " - " + filenameSplit[1],
                                  "status" => "DESIGN",
                                  "creationDate" => DateTime.now.strftime('%Q'),
                                  "lastModified" => DateTime.now.strftime('%Q'),
                                  "script" => Rails.application.config.serversIP["serverIP"] + geppettoTmpPath + @geppettoJsFilePath,
                                  "aspectConfigurations" => [
                                    {
                                      "id" => 1,
                                      "instance" => target[0],
                                      "simulatorConfiguration" => {
                                        "id" => 1,
                                        "simulatorId" => "neuronSimulator",
                                        "timestep" => 0.000025,
                                        "length" => 0.3
                                      }
                                    }
                                  ] 
                                }],
              "geppettoModel"=> { "id" => 1, "url" => Rails.application.config.serversIP["serverIP"] + geppettoTmpPath + @geppettoModelFilePath, "type" => "GEPPETTO_PROJECT"}
            }
          end

          geppettoJsFile.gsub! entity, target[0]
        
          File.write(publicResourcesPath + geppettoTmpPath + @geppettoJsFilePath, geppettoJsFile)
          geppettoTmpJsFile.close
          
          if ((docType == 'net' || docType == 'cell') && target != nil && target[0] != nil)
            geppettoModelFile = File.read(publicResourcesPath + geppettoResourcesPath + simulationTemplates + "GeppettoNeuroMLModelNetworkCell.xmi")
            geppettoModelFile.gsub! '$TARGET_ID', target[0]
            geppettoSimulationFile["experiments"][0]["aspectConfigurations"][0]["simulatorConfiguration"]["parameters"] = {"target" => target[0]}
          else  
            geppettoModelFile = File.read(publicResourcesPath + geppettoResourcesPath + simulationTemplates + "GeppettoNeuroMLModel.xmi")
          end 
        elsif format == 'swc'
          geppettoModelFile = File.read(publicResourcesPath + geppettoResourcesPath + simulationTemplates + "GeppettoSWCModel.xmi")
        end  
      end 

      geppettoModelFile.gsub! '$ENTER_MODEL_URL', url
      geppettoModelFile.gsub! '$ENTER_ID', target[0]
      geppettoModelFile.gsub! '$ENTER_REFERENCE_URL', (@project!=nil) ? @project.identifier : "testing"
      
      # Write file to disc and change permissions to allow access from Geppetto             
      File.write(publicResourcesPath + geppettoTmpPath + @geppettoSimulationFilePath, geppettoSimulationFile.to_json)
      File.write(publicResourcesPath + geppettoTmpPath + @geppettoModelFilePath, geppettoModelFile)
        
      geppettoTmpSimulationFile.close
      geppettoTmpModelFile.close 
        
      geppettoSimulationFileObj = {"geppettoSimulationFile" => geppettoTmpPath + @geppettoSimulationFilePath}
      return geppettoSimulationFileObj
  end
end
