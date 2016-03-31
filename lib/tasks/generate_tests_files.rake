task :generate_tests_files => :environment do
  require 'tempfile'
  require 'logger'

  include ApplicationHelper
  include ProjectsHelper  
  
  #Set the logger to stdoutput
  logger = Logger.new(STDOUT)
  logger.level     = Logger::INFO
  Rails.logger     = logger

  #Read blacklisted models (these models do not run in Geppetto)
  blackListedModels = readFileAsArray('lib/tasks/blackListedModels')
  
  #Read blacklisted projects (these models do not run in Geppetto)
  blackListedProjects = readFileAsArray('lib/tasks/blackListedProjects')
  
  #Iterate all the projects extracting all nml files
  projects = []
  Project.all.each do |project|
    
    if (project.repository != nil && File.directory?(project.repository.url) && blackListedProjects.exclude?(project.identifier))
      #Get nml Files
      nmlFiles = getNML2Files(project.repository)
      
      #Get repo url and path  
      repourl = getHttpRepositoryURL(project)
      repopath = getHttpRepositoryPath(project.repository)

      models = []
      #Add files to projectsFiles list unless they are blacklisted
      for nmlFile in nmlFiles 
        modelUrl = repourl + repopath + nmlFile
        unless (blackListedModels.include?(modelUrl))
          features = []
          if nmlFile.end_with?("net.nml") || nmlFile.end_with?("cell.nml")
            features.push("hasInstance")
          end  
          models.push({"name" => modelUrl, "url" => Rails.application.config.serversIP["serverIP"] + generateGEPPETTOSimulationFileFromUrl(modelUrl, 10000000)["geppettoSimulationFile"], "features" => features})
        end
      end
      
      if (models.length > 0 )
          projects.push({"name" => project.name, "description" => repourl, "testModels" => models})
      end
    end
    
  end
  
  #Write to file
  fileContent = {"testModules"=>projects}
  File.write('public/geppetto/tmp/testFile', fileContent.to_json)
  
end
  
  
