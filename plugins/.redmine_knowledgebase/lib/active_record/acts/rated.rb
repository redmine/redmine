# Copyright (c) 2007 Guy Naor (Famundo LLC)
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module ActiveRecord #:nodoc:
  module Acts #:nodoc:

    # == acts_as_rated
    # Adds rating capabilities to any ActiveRecord object.
    # It has the ability to work with objects that have or don't special fields to keep a tally of the 
    # ratings and number of votes for each object. 
    # In addition it will by default use the User model as the rater object and keep the ratings per-user.
    # It can be configured to use another class, or not use a rater at all, just keeping a global rating
    #
    # Special methods are provided to create the ratings table and if needed, to add the special fields needed
    # to keep per-objects ratings fast for access to rated objects. Can be easily used in migrations.
    #
    # == Example of usage:
    #
    #   class Book < ActiveRecord::Base
    #     acts_as_rated
    #   end
    #
    #   bill = User.find_by_name 'bill'
    #   jill = User.find_by_name 'jill'
    #   catch22 = Book.find_by_title 'Catch 22'
    #   hobbit  = Book.find_by_title 'Hobbit'
    #
    #   catch22.rate 5, bill
    #   hobbit.rate  3, bill
    #   catch22.rate 1, jill
    #   hobbit.rate  5, jill
    #
    #   hobbit.rating_average # => 4
    #   hobbit.rated_total    # => 8
    #   hobbit.rated_count    # => 2
    #
    #   hobbit.unrate bill 
    #   hobbit.rating_average # => 5
    #   hobbit.rated_total    # => 5
    #   hobbit.rated_count    # => 1
    #
    #   bks = Book.find_by_rating 5     # => [hobbit]
    #   bks = Book.find_by_rating 1..5  # => [catch22, hobbit]
    #
    #   usr = Book.find_rated_by jill   # => [catch22, hobbit]
    #
    module Rated
     
      class RateError < RuntimeError; end
      
      def self.included(base) #:nodoc:
        base.extend(ClassMethods)  
      end
      
      module ClassMethods

        # Make the model ratable. Can work both with and without a rater entity (defaults to User).
        # The Rating model, holding the details of the ratings, will be created dynamically if it doesn't exist.
        # 
        # * Adds a <tt>has_many :ratings</tt> association to the model for easy retrieval of the detailed ratings.
        # * Adds a <tt>has_many :raters</tt> association to the onject, unless <tt>:no_rater</tt> is given as a configuration parameter.
        # * Adds a <tt>has_many :ratings</tt> associations to the rater class.
        # * Adds a <tt>has_one :rating_statistic</tt> association to the model, if <tt>:with_stats_table => true</tt> is given as a configuration param.
        #
        # === Options
        # * <tt>:rating_class</tt> - 
        #   class of the model used for the ratings. Defaults to Rating. This class will be dynamically created if not already defined.
        #   If the class is predefined, it must have in it the following definitions:
        #   <tt>belongs_to :rated, :polymorphic => true</tt> and if using a rater (which is true in most cases, see below) also 
        #   <tt>belongs_to :rater, :class_name => 'User', :foreign_key => :rater_id</tt> replace user with the rater class if needed.
        # * <tt>:rater_class</tt> - 
        #   class of the model that creates the rating. 
        #   Defaults to User This class will NOT be created, so it must be defined in the app. 
        #   Another option will be to keep a session or IP based ID here to prevent multiple ratings from the same client.
        # * <tt>:no_rater</tt> - 
        #   do not keep track of who created the rating. This will change the behaviour
        #   to one that just collects and averages ratings, but doesn't keep track of who
        #   posted the rating. Useful in a public application that doesn't care about
        #   individual votes
        # * <tt>:rating_range</tt> - 
        #   A range object for the acceptable rating value range. Defaults to not limited
        # * <tt>:with_stats_table</tt> -
        #   Use a separate statistics table to hold the count/total/average rating of the rated object instead of adding the columns to the object's table.
        #   This means we do not have to change the model table. It still holds a big performance advantage over using SQL to get the statistics
        # * <tt>:stats_class -
        #   Class of the statics table model. Only needed if <tt>:with_stats_table</tt> is set to true. Default to RatingStat. 
        #   This class need to have the following defined: <tt>belongs_to :rated, :polymorphic => true</tt>.
        #   And must make sure that it has the attributes <tt>rating_count</tt>, <tt>rating_total</tt> and <tt>rating_avg</tt> and those
        #   must be initialized to 0 on new instances
        #   
        def acts_as_rated(options = {})
          # don't allow multiple calls
          return if self.included_modules.include?(ActiveRecord::Acts::Rated::RateMethods)
          send :include, ActiveRecord::Acts::Rated::RateMethods
                    
          # Create the model for ratings if it doesn't yet exist
          rating_class = options[:rating_class] || 'Rating'
          rater_class  = options[:rater_class]  || 'User'
          stats_class  = options[:stats_class]  || 'RatingStatistic' if options[:with_stats_table]

          unless Object.const_defined?(rating_class)
            Object.class_eval <<-EOV
              class #{rating_class} < ActiveRecord::Base
                belongs_to :rated, :polymorphic => true
                #{options[:no_rater] ? '' : "belongs_to :rater, :class_name => #{rater_class}, :foreign_key => :rater_id"}
              end
            EOV
          end

          unless stats_class.nil? || Object.const_defined?(stats_class)
            Object.class_eval <<-EOV
              class #{stats_class} < ActiveRecord::Base
                belongs_to :rated, :polymorphic => true
              end
            EOV
          end
         
          raise RatedError, ":rating_range must be a range object" unless options[:rating_range].nil? || (Range === options[:rating_range])
          
          # Rails < 3
          # write_inheritable_attribute( :acts_as_rated_options , 
          #                                { :rating_range => options[:rating_range], 
          #                                  :rating_class => rating_class,
          #                                  :stats_class => stats_class,
          #                                  :rater_class => rater_class } )
          # class_inheritable_reader :acts_as_rated_options
          
          # Rails >= 3
          class_attribute :acts_as_rated_options
          self.acts_as_rated_options = { :rating_range => options[:rating_range], 
                                         :rating_class => rating_class,
                                         :stats_class => stats_class,
                                         :rater_class => rater_class }
          class_eval do
            has_many :ratings, :as => :rated, :dependent => :delete_all, :class_name => rating_class.to_s
            has_many(:raters, :through => :ratings, :class_name => rater_class.to_s) unless options[:no_rater]
            has_one(:rating_statistic, :class_name => stats_class.to_s, :as => :rated, :dependent => :delete) unless stats_class.nil?

            before_create :init_rating_fields
          end

          # Add to the User (or whatever the rater is) a has_many ratings if working with a rater
          return if options[:no_rater] 
          rater_as_class = rater_class.constantize
          return if rater_as_class.instance_methods.include?('find_in_ratings')
          rater_as_class.class_eval <<-EOS
            has_many :ratings, :foreign_key => :rater_id, :class_name => #{rating_class.to_s}
          EOS
        end
      end

      module RateMethods
      
        def self.included(base) #:nodoc:
          base.extend ClassMethods
        end

        # Get the average based on the special fields, 
        # or with a SQL query if the rated objects doesn't have the avg and count fields
        def rating_average
          return self.rating_avg if attributes.has_key?('rating_avg')
          return (rating_statistic.rating_avg || 0) rescue 0 if acts_as_rated_options[:stats_class]
          avg = ratings.average(:rating) 
          avg = 0 if avg.nil? or avg.nan?
          avg
        end

        # Is this object rated already?
        def rated?
          return (!self.rating_count.nil? && self.rating_count > 0) if attributes.has_key? 'rating_count'
          if acts_as_rated_options[:stats_class]
            stats = (rating_statistic.rating_count || 0) rescue 0
            return stats > 0
          end

          # last is the one where we don't keep the statistics - go direct to the db
          !ratings.first.nil? 
        end
        
        # Get the number of ratings for this object based on the special fields, 
        # or with a SQL query if the rated objects doesn't have the avg and count fields
        def rated_count
          return self.rating_count || 0 if attributes.has_key? 'rating_count'
          return (rating_statistic.rating_count || 0) rescue 0 if acts_as_rated_options[:stats_class]
          ratings.count 
        end

        # Get the sum of all ratings for this object based on the special fields, 
        # or with a SQL query if the rated objects doesn't have the avg and count fields
        def rated_total
          return self.rating_total || 0 if attributes.has_key? 'rating_total'
          return (rating_statistic.rating_total || 0) rescue 0 if acts_as_rated_options[:stats_class]
          ratings.sum(:rating) 
        end
            
        # Rate the object with or without a rater - create new or update as needed
        #
        # * <tt>value</tt> - the value to rate by, if a rating range was specified will be checked that it is in range
        # * <tt>rater</tt> - an object of the rater class. Must be valid and with an id to be used.
        #                    If the acts_as_rated was passed :with_rater => false, this parameter is not required
        def rate value, rater = nil
          # Sanity checks for the parameters
          rating_class = acts_as_rated_options[:rating_class].constantize
          with_rater = rating_class.column_names.include? "rater_id"
          raise RateError, "rating with no rater cannot accept a rater as a parameter" if !with_rater && !rater.nil?
          if with_rater && !(acts_as_rated_options[:rater_class].constantize === rater)
            raise RateError, "the rater object must be the one used when defining acts_as_rated (or a descendent of it). other objects are not acceptable"
          end
          raise RateError, "rating with rater must receive a rater as parameter" if with_rater && (rater.nil? || rater.id.nil?)
          r = with_rater ? ratings.where(:conditions => ['rater_id = ?', rater.id]).first : nil
          raise RateError, "value is out of range!" unless acts_as_rated_options[:rating_range].nil? || acts_as_rated_options[:rating_range] === value
          
          # Find the place to store the rating statistics if any...
          # Take care of the case of a separate statistics table
          unless acts_as_rated_options[:stats_class].nil? || @rating_statistic.class.to_s == acts_as_rated_options[:stats_class]
            self.rating_statistic = acts_as_rated_options[:stats_class].constantize.new    
          end
          target = self if attributes.has_key? 'rating_total'
          target ||= self.rating_statistic if acts_as_rated_options[:stats_class]
          rating_class.transaction do
            if r.nil?
              rate = rating_class.new
              rate.rater_id = rater.id if with_rater
              if target
                target.rating_count = (target.rating_count || 0) + 1 
                target.rating_total = (target.rating_total || 0) + value
                target.rating_avg = target.rating_total / target.rating_count
              end
              ratings << rate
            else
              rate = r
              if target
                target.rating_total += value - rate.rating # Update the total rating with the new one
                target.rating_avg = target.rating_total / target.rating_count 
              end
            end

            # Remove the actual ratings table entry
            rate.rating = value
            if !new_record?
              rate.save
              target.save if target
            end
          end
        end

        # Unrate the rating of the specified rater object.
        # * <tt>rater</tt> - an object of the rater class. Must be valid and with an id to be used
        #
        # Unrate cannot be called for acts_as_rated with :with_rater => false
        def unrate rater
          rating_class = acts_as_rated_options[:rating_class].constantize
          if !(acts_as_rated_options[:rater_class].constantize === rater)
            raise RateError, "The rater object must be the one used when defining acts_as_rated (or a descendent of it). other objects are not acceptable" 
          end
          raise RateError, "Rater must be a valid and existing object" if rater.nil? || rater.id.nil?
          raise RateError, 'Cannot unrate if not using a rater' if !rating_class.column_names.include? "rater_id"
          r = ratings.where(:conditions => ['rater_id = ?', rater.id]).first
          if !r.nil?
            target = self if attributes.has_key? 'rating_total'
            target ||= self.rating_statistic if acts_as_rated_options[:stats_class]
            if target
              rating_class.transaction do
                target.rating_count -= 1
                target.rating_total -= r.rating
                target.rating_avg = target.rating_total / target.rating_count
                target.rating_avg = 0 if target.rating_avg.nan?
              end
            end

            # Removing the ratings table entry
            r.destroy
            target.save if !target.nil?
          end
        end

        # Check if an item was already rated by the given rater
        def rated_by? rater
          rating_class = acts_as_rated_options[:rating_class].constantize
          if !(acts_as_rated_options[:rater_class].constantize === rater)
             raise RateError, "The rater object must be the one used when defining acts_as_rated (or a descendent of it). other objects are not acceptable" 
          end
          raise RateError, "Rater must be a valid and existing object" if rater.nil? || rater.id.nil?
          raise RateError, 'Rater must be a valid rater' if !rating_class.column_names.include? "rater_id"
          ratings.count(:conditions => ['rater_id = ?', rater.id]) > 0
        end
            
        private

        def init_rating_fields #:nodoc:
          if attributes.has_key? 'rating_total'
            self.rating_count ||= 0 
            self.rating_total ||= 0
            self.rating_avg   ||= 0
          end
        end 

      end  

      module ClassMethods

        # Generate the ratings columns on a table, to be used when creating the table
        # in a migration. This is the preferred way to do in a migration that creates
        # new tables as it will make it as part of the table creation, and not generate
        # ALTER TABLE calls after the fact
        def generate_ratings_columns table
          table.column :rating_count, :integer
          table.column :rating_total, :decimal
          table.column :rating_avg,   :decimal, :precision => 10, :scale => 2
        end

        # Create the needed columns for acts_as_rated. 
        # To be used during migration, but can also be used in other places.
        def add_ratings_columns
          if !self.content_columns.find { |c| 'rating_count' == c.name }
            self.connection.add_column table_name, :rating_count, :integer
            self.connection.add_column table_name, :rating_total, :decimal
            self.connection.add_column table_name, :rating_avg,   :decimal, :precision => 10, :scale => 2
            self.reset_column_information
          end            
        end

        # Remove the acts_as_rated specific columns added with add_ratings_columns
        # To be used during migration, but can also be used in other places
        def remove_ratings_columns
          if self.content_columns.find { |c| 'rating_count' == c.name }
            self.connection.drop_column table_name, :rating_count
            self.connection.drop_column table_name, :rating_total
            self.connection.drop_column table_name, :rating_avg
            self.reset_column_information
          end            
        end

        # Create the ratings table
        # === Options hash:
        # * <tt>:with_rater</tt> - add the rated_id column
        # * <tt>:table_name</tt> - use a table name other than ratings 
        # * <tt>:with_stats_table</tt> - create also a rating statistics table
        # * <tt>:stats_table_name</tt> - the name of the rating statistics table. Defaults to :rating_statistics
        # To be used during migration, but can also be used in other places
        def create_ratings_table options = {}
          with_rater  = options[:with_rater] != false 
          name        = options[:table_name] || :ratings
          stats_table = options[:stats_table_name] || :rating_statistics if options[:with_stats_table]
          self.connection.create_table(name) do |t|
            t.column(:rater_id,   :integer) unless !with_rater
            t.column :rated_id,   :integer
            t.column :rated_type, :string
            t.column :rating,     :decimal 
          end

          self.connection.add_index(name, :rater_id) unless !with_rater
          self.connection.add_index name, [:rated_type, :rated_id]
          
          unless stats_table.nil?
            self.connection.create_table(stats_table) do |t|
              t.column :rated_id,     :integer
              t.column :rated_type,   :string
              t.column :rating_count, :integer
              t.column :rating_total, :decimal
              t.column :rating_avg,   :decimal, :precision => 10, :scale => 2
            end
          
            self.connection.add_index stats_table, [:rated_type, :rated_id]
          end

        end

        # Drop the ratings table. 
        # === Options hash:
        # * <tt>:table_name</tt> - the name of the ratings table, defaults to ratings
        # * <tt>:with_stats_table</tt> - remove the special rating statistics as well
        # * <tt>:stats_table_name</tt> - the statistics table name. Defaults to :rating_statistics
        # To be used during migration, but can also be used in other places
        def drop_ratings_table options = {}
          name = options[:table_name] || :ratings
          stats_table = options[:stats_table_name] || :rating_statistics if options[:with_stats_table]
          self.connection.drop_table name 
          self.connection.drop_table stats_table unless stats_table.nil? 
        end
          
        # Find all ratings for a specific rater.
        # Will raise an error if this acts_as_rated is without a rater.
        def find_rated_by rater
          rating_class = acts_as_rated_options[:rating_class].constantize
          raise RateError, "The rater object must be the one used when defining acts_as_rated (or a descendent of it). other objects are not acceptable" if !(acts_as_rated_options[:rater_class].constantize === rater)
          raise RateError, 'Cannot find_rated_by if not using a rater' if !rating_class.column_names.include? "rater_id"
          raise RateError, "Rater must be an existing object with an id" if rater.id.nil?
          rated_class = ActiveRecord::Base.send(:class_name_of_active_record_descendant, self).to_s
          conds = [ 'rated_type = ? AND rater_id = ?', rated_class, rater.id ]
          acts_as_rated_options[:rating_class].constantize.where(:conditions => conds).collect {|r| r.rated_type.constantize.find_by_id r.rated.id }
        end

       
        # Find by rating - pass either a specific value or a range and the precision to calculate with
        # * <tt>value</tt> - the value to look for or a range
        # * <tt>precision</tt> - number of decimal digits to round to. Default to 10. Use 0 for integer numbers comparision
        # * <tt>round_it</tt> - round the rating average before comparing?. Defaults to true. Passing false will result in a faster query
        def find_by_rating value, precision = 10, round = true
          rating_class = acts_as_rated_options[:rating_class].constantize
          if column_names.include? "rating_avg"
            if Range === value 
              conds = round ? [ 'round(rating_avg, ?) BETWEEN ? AND ?', precision.to_i, value.begin, value.end ] : 
                              [ 'rating_avg BETWEEN ? AND ?', value.begin, value.end ]
            else
              conds = round ? [ 'round(rating_avg, ?) = ?', precision.to_i, value ] : [ 'rating_avg = ?', value ]
            end
            find :all, :conditions => conds
          else
            if round
              base_sql = <<-EOS
                select #{table_name}.*,round(COALESCE(average,0), #{precision.to_i}) AS rating_average from #{table_name} left outer join
                  (select avg(rating) as average, rated_id  
                     from #{rating_class.table_name}
                     where rated_type = '#{class_name}' 
                     group by rated_id) as rated 
                     on rated_id=id 
              EOS
            else
              base_sql = <<-EOS
                select #{table_name}.*,COALESCE(average,0) AS rating_average from #{table_name} left outer join
                  (select avg(rating) as average, rated_id  
                     from #{rating_class.table_name}
                     where rated_type = '#{class_name}' 
                     group by rated_id) as rated 
                     on rated_id=id 
              EOS
            end
            if Range === value
              if round
                where_part = " WHERE round(COALESCE(average,0), #{precision.to_i}) BETWEEN  #{connection.quote(value.begin)} AND #{connection.quote(value.end)}"
              else
                where_part = " WHERE COALESCE(average,0) BETWEEN #{connection.quote(value.begin)} AND #{connection.quote(value.end)}"
              end
            else
              if round
                where_part = " WHERE round(COALESCE(average,0), #{precision.to_i}) = #{connection.quote(value)}"
              else
                where_part = " WHERE COALESCE(average,0) = #{connection.quote(value)}"
              end
            end

            find_by_sql base_sql + where_part
          end
        end          
      end
      
    end
  end
end


ActiveRecord::Base.send :include, ActiveRecord::Acts::Rated

