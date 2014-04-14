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

class SearchCustomFieldController < ApplicationController
  include ApplicationHelper
  
  def index
    search_projects_by_custom_fields()
  end
  
  def search_projects_by_custom_fields
    @query = ProjectCustomField.select("id, name, possible_values, field_format")
        
    @projects = nil
    
    if !params[:op].blank? and !params[:v].blank?
      
      #add_filters(params[:fields] || params[:f], params[:operators] || params[:op], params[:values] || params[:v])
      
      conditions  = String.new
      operator = params[:op]
      operatorValues = params[:v]
      operator.each do |operatorKey, operatorItem|
        custom_field_value = ActiveRecord::Base.connection.quote(operatorValues[operatorKey].first)
        
        conditions << " AND " unless conditions.length == 0
        conditions << "cf.id = " + operatorKey + " AND cv.value " + operatorItem + custom_field_value
      end
      
      #params.each_key do |key|
        #if key != 'action' and key != 'controller' then
          #custom_field_name = ActiveRecord::Base.connection.quote(key)
          #custom_field_value = ActiveRecord::Base.connection.quote(params[key])
          
          #conditions << " AND " unless conditions.length == 0
          #conditions << "cf.name = " + custom_field_name + " AND cv.value= " + custom_field_value
        #end  
      #end
  
      query = "SELECT p.id, p.updated_on, p.identifier, p.name, p.description FROM #{CustomField.table_name} cf INNER JOIN #{CustomValue.table_name} cv ON cf.id=cv.custom_field_id INNER JOIN #{Project.table_name} p ON cv.customized_id=p.id"
      query << " WHERE " + conditions  
      
      print query
          
      @projects ||= ActiveRecord::Base.connection.select(query);
    end
    

  end
  
end
