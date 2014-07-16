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

module DocHelper
  include ApplicationHelper

  def customiseTitle(fileDoc, removeOrderPrefix = false)
    fileName = File.basename(fileDoc, ".md")
    if removeOrderPrefix
      fileName = fileName[3..-1]
    end
    return fileName.gsub('_',' ')
  end
  
  def getDivId(fileDoc)
    File.basename(fileDoc, ".md")[3..-1]
  end  
  
#  def getVideoDiv(videoPath, width = 320, height = 240)
#    #videoUrl = 'https://github.com/OpenSourceBrain/OSB_Documentation/contents'
#    videoUrl = '/home/adrian/code/osb-code/OSB_Documentation/resources/videos/' + videoPath
#
#    return "<video width='" + width + "' height='" + height + "' controls>/
#      <source src='" + videoUrl + ".mp4' type='video/mp4'>/
#      <source src='" + videoUrl + ".ogg' type='video/ogg'>/
#      <object data='" + videoUrl + ".mp4' width='" + width + "' height='" + height + "'>/
#        <embed src='" + videoUrl + ".swf' width='" + width + "' height='" + height + "'>/
#      </object> 
#    </video>"
#  end  
end
