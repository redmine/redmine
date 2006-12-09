class Query < ActiveRecord::Base
  serialize :filters
  
  validates_presence_of :name
    
  @@operators = { "="   => "Egal", 
                  "!"   => "Different",
                  "o"   => "Ouvert",
                  "c"   => "Ferme",
                  "!*"  => "Aucun",
                  "*"   => "Tous",
                  "<t+" => "Dans moins de",
                  ">t+" => "Dans plus de",
                  "t+"  => "Dans exactement",
                  "t"   => "Aujourd'hui",
                  ">t-" => "Il y a moins de",
                  "<t-" => "Il y a plus de",
                  "t-"  => "Il y a exactement" }
    
  @@operators_by_filter_type = { :list => [ "=", "!" ],
                                 :list_status => [ "o", "=", "!", "c" ],
                                 :list_optional => [ "=", "!", "!*", "*" ],
                                 :date => [ "<t+", ">t+", "t+", "t", ">t-", "<t-", "t-" ],
                                 :date_past => [ ">t-", "<t-", "t-", "t" ] }
  
  @@available_filters = { "status_id" => { :type => :list_status, :order => 1,
                                           :values => IssueStatus.find(:all).collect{|s| [s.name, s.id.to_s] } },       
                          "tracker_id" => { :type => :list, :order => 2,
                                            :values => Tracker.find(:all).collect{|s| [s.name, s.id.to_s] } },                                                                   
                          "assigned_to_id" => { :type => :list_optional, :order => 3,
                                                :values => User.find(:all).collect{|s| [s.display_name, s.id.to_s] } },                                                
                          "priority_id" => { :type => :list, :order => 4,
                                             :values => Enumeration.find(:all, :conditions => ['opt=?','IPRI']).collect{|s| [s.name, s.id.to_s] } },                        
                          "created_on" => { :type => :date_past, :order => 5 },                        
                          "updated_on" => { :type => :date_past, :order => 6 },
                          "start_date" => { :type => :date, :order => 7 },
                          "due_date" => { :type => :date, :order => 8 } }
                          
  cattr_accessor :available_filters

  def initialize(attributes = nil)
    super
    self.filters ||= { 'status_id' => {:operator => "o"} }
  end
  
  def validate
    errors.add_to_base "Au moins un critere doit etre selectionne" unless filters && !filters.empty?
    filters.each_key do |field|
      errors.add field.gsub(/\_id$/, ""), "doit etre renseigne" unless 
          # filter requires one or more values
          (values_for(field) and !values_for(field).first.empty?) or 
          # filter doesn't require any value
          ["o", "c", "!*", "*", "t"].include? operator_for(field)
    end if filters
  end  
  
  def add_filter(field, operator, values)
    # values must be an array
    return unless values and values.is_a? Array
    # check if field is defined as an available filter
    if @@available_filters.has_key? field
      filter_options = @@available_filters[field]
      # check if operator is allowed for that filter
      if @@operators_by_filter_type[filter_options[:type]].include? operator
        filters[field] = {:operator => operator, :values => values }
      end
    end
  end
      
  def has_filter?(field)
    filters and filters[field]
  end
  
  def operator_for(field)
    has_filter?(field) ? filters[field][:operator] : nil
  end
  
  def values_for(field)
    has_filter?(field) ? filters[field][:values] : nil
  end
  
  def statement
    sql = "1=1" 
    filters.each_key do |field|
      sql = sql + " AND " unless sql.empty?      
      v = values_for field      
      case operator_for field
      when "="
        sql = sql + "issues.#{field} IN (" + v.each(&:to_i).join(",") + ")"
      when "!"
        sql = sql + "issues.#{field} NOT IN (" + v.each(&:to_i).join(",") + ")"
      when "!*"
        sql = sql + "issues.#{field} IS NULL"
      when "*"
        sql = sql + "issues.#{field} IS NOT NULL"
      when "o"
        sql = sql + "issue_statuses.is_closed=#{connection.quoted_false}" if field == "status_id"
      when "c"
        sql = sql + "issue_statuses.is_closed=#{connection.quoted_true}" if field == "status_id"
      when ">t-"
        sql = sql + "issues.#{field} >= '%s'" % connection.quoted_date(Date.today - v.first.to_i)
      when "<t-"
        sql = sql + "issues.#{field} <= '" + (Date.today - v.first.to_i).strftime("%Y-%m-%d") + "'"
      when "t-"
        sql = sql + "issues.#{field} = '" + (Date.today - v.first.to_i).strftime("%Y-%m-%d") + "'"
      when ">t+"
        sql = sql + "issues.#{field} >= '" + (Date.today + v.first.to_i).strftime("%Y-%m-%d") + "'"
      when "<t+"
        sql = sql + "issues.#{field} <= '" + (Date.today + v.first.to_i).strftime("%Y-%m-%d") + "'"
      when "t+"
        sql = sql + "issues.#{field} = '" + (Date.today + v.first.to_i).strftime("%Y-%m-%d") + "'"
      when "t"
        sql = sql + "issues.#{field} = '%s'" % connection.quoted_date(Date.today)
      end
    end if filters
    sql
  end

  def self.operators_for_select(filter_type)
    @@operators_by_filter_type[filter_type].collect {|o| [@@operators[o], o]}
  end
 
end
