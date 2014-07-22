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

class DocController < ApplicationController
  include ApplicationHelper
  def index
#    @path = params[:path] || 'Help'
    @path = params[:path]  
          
#    docRepoUrl = 'https://github.com/OpenSourceBrain/OSB_Documentation/contents' + @path + '/*'
#    docRepoFolder = '/home/adrian/code/osb-code/OSB_Documentation/contents/' + @path + '/*'
    docRepoFolder = '/home/documentation/OSB_Documentation/contents/' + @path + '/*'
    
#   Read files in dir
    filesAndDirDoc = Dir[docRepoFolder]
    dirsDoc = Dir[docRepoFolder + '/']
    @filesDoc = filesAndDirDoc
    dirsDoc.each do |dirDoc|
      @filesDoc.delete(dirDoc[0..-2])
    end    
    @filesDoc.sort!
    
#    Read content for each file
#    @helpContent = {}
#    filesDoc.each do |fileDoc|
#      #@helpContent[fileDoc] = textilizable(open(docRepoUrl + fileDoc).read)
#      print "fileDoc",fileDoc
#      @helpContent[fileDoc] = textilizable(open(fileDoc).read)
#    end

          
  end
  
end
