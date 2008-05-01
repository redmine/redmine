# Copyright (c) 2005-2007 David Barri

require 'date'

module ActionView #:nodoc:
  module Helpers #:nodoc:
    module DateHelper
    
      unless const_defined?(:LOCALIZED_HELPERS)
        LOCALIZED_HELPERS= true
        LOCALIZED_MONTHNAMES = {}
        LOCALIZED_ABBR_MONTHNAMES = {}
      end
      
      # This method uses <tt>current_language</tt> to return a localized string.
      def distance_of_time_in_words(from_time, to_time = 0, include_seconds = false)
        from_time = from_time.to_time if from_time.respond_to?(:to_time)
        to_time = to_time.to_time if to_time.respond_to?(:to_time)
        distance_in_minutes = (((to_time - from_time).abs)/60).round
        distance_in_seconds = ((to_time - from_time).abs).round

        case distance_in_minutes
          when 0..1
            return (distance_in_minutes==0) ? l(:actionview_datehelper_time_in_words_minute_less_than) : l(:actionview_datehelper_time_in_words_minute_single) unless include_seconds
            case distance_in_seconds
              when 0..4   then lwr(:actionview_datehelper_time_in_words_second_less_than, 5)
              when 5..9   then lwr(:actionview_datehelper_time_in_words_second_less_than, 10)
              when 10..19 then lwr(:actionview_datehelper_time_in_words_second_less_than, 20)
              when 20..39 then l(:actionview_datehelper_time_in_words_minute_half)
              when 40..59 then l(:actionview_datehelper_time_in_words_minute_less_than)
              else             l(:actionview_datehelper_time_in_words_minute_single)
            end

          when 2..44           then lwr(:actionview_datehelper_time_in_words_minute, distance_in_minutes)
          when 45..89          then l(:actionview_datehelper_time_in_words_hour_about_single)
          when 90..1439        then lwr(:actionview_datehelper_time_in_words_hour_about, (distance_in_minutes.to_f / 60.0).round)
          when 1440..2879      then lwr(:actionview_datehelper_time_in_words_day, 1)
          when 2880..43199     then lwr(:actionview_datehelper_time_in_words_day, (distance_in_minutes / 1440).round)
          when 43200..86399    then l(:actionview_datehelper_time_in_words_month_about)
          when 86400..525959   then lwr(:actionview_datehelper_time_in_words_month,(distance_in_minutes / 43200).round)
          when 525960..1051919 then l(:actionview_datehelper_time_in_words_year_about)
          else                      lwr(:actionview_datehelper_time_in_words_year_over,(distance_in_minutes / 525960).round)
        end
      end
      
      # The order of d/m/y depends on the language (unless already specified in the options hash).
      def date_select_with_gloc(object_name, method, options = {})
        options[:order] ||= l(:actionview_datehelper_date_select_order)
        date_select_without_gloc(object_name, method, options)
      end
      alias_method_chain :date_select, :gloc
      
      # The order of d/m/y depends on the language (unless already specified in the options hash).
      def datetime_select_with_gloc(object_name, method, options = {})
        options[:order] ||= l(:actionview_datehelper_date_select_order)
        datetime_select_without_gloc(object_name, method, options)
      end
      alias_method_chain :datetime_select, :gloc
      
      # This method has been modified so that a localized string can be appended to the day numbers.
      def select_day(date, options = {})
        if options[:use_hidden]
          val = date ? (date.kind_of?(Fixnum) ? date : date.day) : ''
          hidden_html(options[:field_name] || 'day', val, options)
        else
          day_options = []
          suffix = l :actionview_datehelper_select_day_suffix
          
          if options.has_key?(:min_date) && options.has_key?(:max_date)
            if options[:min_date].year == options[:max_date].year && options[:min_date].month == options[:max_date].month
              start_day, end_day = options[:min_date].day, options[:max_date].day
            end
          end
          start_day ||= 1
          end_day ||= 31
          
          start_day.upto(end_day) do |day|
            day_options << ((date && (date.kind_of?(Fixnum) ? date : date.day) == day) ?
              %(<option value="#{day}" selected="selected">#{day}#{suffix}</option>\n) :
              %(<option value="#{day}">#{day}#{suffix}</option>\n)
            )
          end
          select_html(options[:field_name] || 'day', day_options, options)
        end
      end
      
      # This method has been modified so that
      # * the month names are localized.
      # * it uses options: <tt>:min_date</tt>, <tt>:max_date</tt>, <tt>:start_month</tt>, <tt>:end_month</tt>
      # * a localized string can be appended to the month numbers when the <tt>:use_month_numbers</tt> option is specified.
      def select_month(date, options = {})
        if options[:use_hidden]
          val = date ? (date.kind_of?(Fixnum) ? date : date.month) : ''
          hidden_html(options[:field_name] || 'month', val, options)
        else
          
          unless LOCALIZED_MONTHNAMES.has_key?(current_language)
            LOCALIZED_MONTHNAMES[current_language] = [''] + l(:general_text_month_names)
            LOCALIZED_ABBR_MONTHNAMES[current_language] = [''] + l(:general_text_month_names_abbr)
          end
          
          month_options = []
          month_names = options[:use_short_month] ? LOCALIZED_ABBR_MONTHNAMES[current_language] : LOCALIZED_MONTHNAMES[current_language]
          
          if options.has_key?(:min_date) && options.has_key?(:max_date)
            if options[:min_date].year == options[:max_date].year
              start_month, end_month = options[:min_date].month, options[:max_date].month
            end
          end
          start_month ||= (options[:start_month] || 1)
          end_month ||= (options[:end_month] || 12)
          suffix = l :actionview_datehelper_select_month_suffix
          
          start_month.upto(end_month) do |month_number|
            month_name = if options[:use_month_numbers]
              "#{month_number}#{suffix}"
            elsif options[:add_month_numbers]
              month_number.to_s + ' - ' + month_names[month_number]
            else
              month_names[month_number]
            end
          
            month_options << ((date && (date.kind_of?(Fixnum) ? date : date.month) == month_number) ?
              %(<option value="#{month_number}" selected="selected">#{month_name}</option>\n) :
              %(<option value="#{month_number}">#{month_name}</option>\n)
            )
          end
          select_html(options[:field_name] || 'month', month_options, options)
        end
      end
      
      # This method has been modified so that
      # * it uses options: <tt>:min_date</tt>, <tt>:max_date</tt>
      # * a localized string can be appended to the years numbers.
      def select_year(date, options = {})
        if options[:use_hidden]
          val = date ? (date.kind_of?(Fixnum) ? date : date.year) : ''
          hidden_html(options[:field_name] || 'year', val, options)
        else
          year_options = []
          y = date ? (date.kind_of?(Fixnum) ? (y = (date == 0) ? Date.today.year : date) : date.year) : Date.today.year
          
          start_year = options.has_key?(:min_date) ? options[:min_date].year : (options[:start_year] || y-5)
          end_year = options.has_key?(:max_date) ? options[:max_date].year : (options[:end_year] || y+5)
          step_val = start_year < end_year ? 1 : -1
          suffix = l :actionview_datehelper_select_year_suffix
          
          start_year.step(end_year, step_val) do |year|
            year_options << ((date && (date.kind_of?(Fixnum) ? date : date.year) == year) ?
              %(<option value="#{year}" selected="selected">#{year}#{suffix}</option>\n) :
              %(<option value="#{year}">#{year}#{suffix}</option>\n)
            )
          end
        select_html(options[:field_name] || 'year', year_options, options)
        end
      end
    end # module DateHelper
    
    # The private method <tt>add_options</tt> is overridden so that "Please select" is localized.
    class InstanceTag
      private
      def add_options(option_tags, options, value = nil)
        option_tags = "<option value=\"\"></option>\n" + option_tags if options[:include_blank]
        if value.blank? && options[:prompt]
          ("<option value=\"\">#{options[:prompt].kind_of?(String) ? options[:prompt] : l(:actionview_instancetag_blank_option)}</option>\n") + option_tags
         else
          option_tags
        end
      end
    end # class InstanceTag
    
  end
end
