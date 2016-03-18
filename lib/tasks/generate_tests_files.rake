task :generate_tests_files => :environment do
  require 'tempfile'
  require 'logger'

  include ApplicationHelper
  include ProjectsHelper  
  
  logger = Logger.new(STDOUT)
  logger.level     = Logger::INFO
  Rails.logger     = logger

  projectsFiles = [];
  Project.all.each do |project|
    
    if (project.repository != nil && File.directory?(project.repository.url))
      nmlFiles = getNML2Files(project.repository)  
      repourl = getHttpRepositoryURL(project)
      repopath=getHttpRepositoryPath(project.repository)
      
      for nmlFile in nmlFiles 
        projectsFiles.push(generateGEPPETTOSimulationFileFromUrl(repourl + repopath + nmlFile)["geppettoSimulationFile"])
        #projectsFiles.push(repourl + repopath + nmlFile);
      end

    end
    
  end
  
  File.write('/tmp/testFile',{"files"=>projectsFiles})
  
end
  
  
