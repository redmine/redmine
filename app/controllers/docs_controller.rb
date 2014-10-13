# redMine - project management software
# Copyright (C) 2006  Jean-Philippe Lang
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

class DocsController < ApplicationController
  include ApplicationHelper
  def index
    @path = params[:path]  
          
    @docRepoUrl = 'https://raw.githubusercontent.com/OpenSourceBrain/OSB_Documentation/master/'
#    docRepoFolder = '/home/adrian/code/osb-code/OSB_Documentation/contents/' + @path + '/*'
#    docRepoFolder = '/home/documentation/OSB_Documentation/contents/' + @path + '/*'
#    @docRepoFolder = '/home/svnsvn/myGitRepositories/OSBDocumentation.git/contents/'
    
    @docProject = Project.find("osb_documentation")
    filesInFolder = listFolderInRepo(@docProject.repository, "contents/" + @path)
    
    @filesDoc = []
    filesInFolder.each do |file|
      if File.extname(file).delete("\n") == ".md"
        @filesDoc << file.delete!("\n")
      end
    end
    @filesDoc.sort!
    
#   Read files in dir
#    filesAndDirDoc = Dir[docRepoFolder]
#    dirsDoc = Dir[docRepoFolder + '/']
#    @filesDoc = filesAndDirDoc
#    dirsDoc.each do |dirDoc|
#      @filesDoc.delete(dirDoc[0..-2])
#    end    
#    @filesDoc.sort!
          
  end
end
