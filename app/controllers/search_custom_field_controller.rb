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
        
    @available_filters = get_available_filters(@query)
    
    @projects = nil
    
    if !params[:op].blank? and !params[:f].blank?
      
      #add_filters(params[:fields] || params[:f], params[:operators] || params[:op], params[:values] || params[:v])
      
      conditions  = String.new
      operator = params[:op]
      operatorValues = params[:v]
      operator.each do |operatorKey, operatorItem|
        #custom_field_value = ActiveRecord::Base.connection.quote(operatorValues[operatorKey].first)
        #conditions << "cf.id = " + operatorKey + " AND cv.value " + operatorItem + custom_field_value
        
        #conditions << " AND " unless conditions.length == 0
        #conditions << "cf.id = " + operatorKey + " AND " + sql_for_field(operatorKey, operatorItem, operatorValues[operatorKey], @available_filters)
        custom_values_table_alias = "cv" + operatorKey
        custom_fields_table_alias = "cf"+ operatorKey
        
        conditions << " INNER JOIN #{CustomValue.table_name} " + custom_values_table_alias + " ON " + custom_values_table_alias + ".customized_id=p.id INNER JOIN #{CustomField.table_name} " + custom_fields_table_alias + " ON " + custom_fields_table_alias + ".id =" + custom_values_table_alias + ".custom_field_id AND " + custom_fields_table_alias + ".id = " + operatorKey + " AND " + sql_for_field(operatorKey, operatorItem, (operatorValues) ? operatorValues[operatorKey] : '', @available_filters, custom_values_table_alias) 
        
      end
      
      #params.each_key do |key|
        #if key != 'action' and key != 'controller' then
          #custom_field_name = ActiveRecord::Base.connection.quote(key)
          #custom_field_value = ActiveRecord::Base.connection.quote(params[key])
          
          #conditions << " AND " unless conditions.length == 0
          #conditions << "cf.name = " + custom_field_name + " AND cv.value= " + custom_field_value
        #end  
      #end
  
      #query = "SELECT p.id, p.updated_on, p.identifier, p.name, p.description FROM #{CustomField.table_name} cf INNER JOIN #{CustomValue.table_name} cv ON cf.id=cv.custom_field_id INNER JOIN #{Project.table_name} p ON cv.customized_id=p.id"
      #query << " WHERE " + conditions  
      
      query = "SELECT p.id, p.updated_on, p.identifier, p.name, p.description FROM #{Project.table_name} p"
      query << conditions
      
     # INNER JOIN #{CustomValue.table_name} cv ON cf.id=cv.custom_field_id INNER JOIN #{Project.table_name} p ON cv.customized_id=p.id"
      #INNER JOIN custom_values cv2 ON cv2.customized_id=p.id INNER JOIN custom_fields cf2 ON cf2.id=cv2.custom_field_id AND cf2.id = 17 AND cv2.value IN ('-1');
      
      #@projects ||= ActiveRecord::Base.connection.select(query);
    @projects = Project.find_by_sql(query);
    end
    

  end
  
  def get_available_filters(query)
    available_filters = {}
    query.each do |queryRow|
      available_filters[queryRow[:id]] = {:type => queryRow[:field_format] != 'int'  ? queryRow[:field_format] : 'integer' || b, :name => queryRow[:name], :values => queryRow[:possible_values]}
    end
    return available_filters
  end
  
  def type_for(field, available_filters)
    available_filters[field][:type] if available_filters.has_key?(field)
  end
  
# Helper method to generate the WHERE sql for a +field+, +operator+ and a +value+
  def sql_for_field(field, operator, value, available_filters, custom_values_table_alias)
    sql = ''
    case operator
    when "="
      if value.any?
        case type_for(field, available_filters)
        #when :date, :date_past
          #sql = date_clause(db_table, db_field, parse_date(value.first), parse_date(value.first))
        when :integer
          #if is_custom_filter
            #sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) = #{value.first.to_i})"
          #else
            sql = custom_values_table_alias + ".value = #{value.first.to_i}"
          #end
        when :float
          #if is_custom_filter
            #sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) BETWEEN #{value.first.to_f - 1e-5} AND #{value.first.to_f + 1e-5})"
          #else
            sql = custom_values_table_alias + ".value BETWEEN #{value.first.to_f - 1e-5} AND #{value.first.to_f + 1e-5}"
          #end
        else
          sql = custom_values_table_alias + ".value IN (" + value.collect{|val| "'#{ActiveRecord::Base.connection.quote_string(val)}'"}.join(",") + ")"
        end
      else
        # IN an empty set
        sql = "1=0"
      end
    when "!"
      if value.any?
        sql = "(" + custom_values_table_alias + ".value IS NULL OR " + custom_values_table_alias + ".value NOT IN (" + value.collect{|val| "'#{ActiveRecord::Base.connection.quote_string(val)}'"}.join(",") + "))"
      else
        # NOT IN an empty set
        sql = "1=1"
      end
    when "!*"
      sql = custom_values_table_alias + ".value IS NULL"
      #sql << " OR #{db_table}.#{db_field} = ''" if is_custom_filter
    when "*"
      sql = custom_values_table_alias + ".value IS NOT NULL"
      #sql << " AND #{db_table}.#{db_field} <> ''" if is_custom_filter
    when ">="
      #if [:date, :date_past].include?(type_for(field))
      #  sql = date_clause(db_table, db_field, parse_date(value.first), nil)
      #else
        #if is_custom_filter
         # sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) >= #{value.first.to_f})"
        #else
          sql = custom_values_table_alias + ".value >= #{value.first.to_f}"
        #end
      #end
    when "<="
      #if [:date, :date_past].include?(type_for(field))
        #sql = date_clause(db_table, db_field, nil, parse_date(value.first))
      #else
        #if is_custom_filter
          #sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) <= #{value.first.to_f})"
        #else
          sql = custom_values_table_alias + ".value <= #{value.first.to_f}"
        #end
      #end
    when "><"
      #if [:date, :date_past].include?(type_for(field))
        #sql = date_clause(db_table, db_field, parse_date(value[0]), parse_date(value[1]))
      #else
        #if is_custom_filter
          #sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) BETWEEN #{value[0].to_f} AND #{value[1].to_f})"
        #else
          sql = custom_values_table_alias + ".value BETWEEN #{value[0].to_f} AND #{value[1].to_f}"
        #end
      #end
    #when "o"
    #  sql = "#{queried_table_name}.status_id IN (SELECT id FROM #{IssueStatus.table_name} WHERE is_closed=#{connection.quoted_false})" if field == "status_id"
    #when "c"
    #  sql = "#{queried_table_name}.status_id IN (SELECT id FROM #{IssueStatus.table_name} WHERE is_closed=#{connection.quoted_true})" if field == "status_id"
    #when "><t-"
      # between today - n days and today
      #sql = relative_date_clause(db_table, db_field, - value.first.to_i, 0)
    #when ">t-"
      # >= today - n days
      #sql = relative_date_clause(db_table, db_field, - value.first.to_i, nil)
    #when "<t-"
      # <= today - n days
      #sql = relative_date_clause(db_table, db_field, nil, - value.first.to_i)
    #when "t-"
      # = n days in past
      #sql = relative_date_clause(db_table, db_field, - value.first.to_i, - value.first.to_i)
    #when "><t+"
      # between today and today + n days
      #sql = relative_date_clause(db_table, db_field, 0, value.first.to_i)
    #when ">t+"
      # >= today + n days
      #sql = relative_date_clause(db_table, db_field, value.first.to_i, nil)
    #when "<t+"
      # <= today + n days
      #sql = relative_date_clause(db_table, db_field, nil, value.first.to_i)
    #when "t+"
      # = today + n days
      #sql = relative_date_clause(db_table, db_field, value.first.to_i, value.first.to_i)
    #when "t"
      # = today
      #sql = relative_date_clause(db_table, db_field, 0, 0)
    #when "ld"
      # = yesterday
      #sql = relative_date_clause(db_table, db_field, -1, -1)
    #when "w"
      # = this week
      #first_day_of_week = l(:general_first_day_of_week).to_i
      #day_of_week = Date.today.cwday
      #days_ago = (day_of_week >= first_day_of_week ? day_of_week - first_day_of_week : day_of_week + 7 - first_day_of_week)
      #sql = relative_date_clause(db_table, db_field, - days_ago, - days_ago + 6)
    #when "lw"
      # = last week
      #first_day_of_week = l(:general_first_day_of_week).to_i
      #day_of_week = Date.today.cwday
      #days_ago = (day_of_week >= first_day_of_week ? day_of_week - first_day_of_week : day_of_week + 7 - first_day_of_week)
      #sql = relative_date_clause(db_table, db_field, - days_ago - 7, - days_ago - 1)
    #when "l2w"
      # = last 2 weeks
      #first_day_of_week = l(:general_first_day_of_week).to_i
      #day_of_week = Date.today.cwday
      #days_ago = (day_of_week >= first_day_of_week ? day_of_week - first_day_of_week : day_of_week + 7 - first_day_of_week)
      #sql = relative_date_clause(db_table, db_field, - days_ago - 14, - days_ago - 1)
    #when "m"
      # = this month
      #date = Date.today
      #sql = date_clause(db_table, db_field, date.beginning_of_month, date.end_of_month)
    #when "lm"
      # = last month
      #date = Date.today.prev_month
      #sql = date_clause(db_table, db_field, date.beginning_of_month, date.end_of_month)
    #when "y"
      # = this year
      #date = Date.today
      #sql = date_clause(db_table, db_field, date.beginning_of_year, date.end_of_year)
    when "~"
      sql = custom_values_table_alias + ".value LIKE '%#{ActiveRecord::Base.connection.quote_string(value.first.to_s.downcase)}%'"
    when "!~"
      sql = custom_values_table_alias + ".value NOT LIKE '%#{ActiveRecord::Base.connection.quote_string(value.first.to_s.downcase)}%'"
    else
      raise "Unknown query operator #{operator}"
    end

    return sql
  end
  
end
