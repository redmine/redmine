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
  blackListedModels = []
  f = File.open('lib/tasks/blackListedModels', "r")
  f.each_line do |line|
    blackListedModels.push(line.strip)
  end
  f.close
  
  #Iterate all the projects extracting all nml files
  projectsFiles = [];
  Project.all.each do |project|
    
    if (project.repository != nil && File.directory?(project.repository.url))
      #Get nml Files
      nmlFiles = getNML2Files(project.repository)
      
      #Get repo url and path  
      repourl = getHttpRepositoryURL(project)
      repopath = getHttpRepositoryPath(project.repository)
      
      #Add files to projectsFiles list unless they are blacklisted
      for nmlFile in nmlFiles 
        modelUrl = repourl + repopath + nmlFile
        unless (blackListedModels.include?(modelUrl))
          projectsFiles.push(Rails.application.config.serversIP["serverIP"] + generateGEPPETTOSimulationFileFromUrl(modelUrl, 10000000)["geppettoSimulationFile"])
        end
      end

    end
    
  end
  
  #Write to file
  fileContent = {"files"=>projectsFiles}
  File.write('public/geppetto/tmp/testFile', fileContent.to_json)
  
end
  
  
