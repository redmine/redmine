# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

require 'uri'

module Redmine
  module FieldFormat
    def self.add(name, klass)
      all[name.to_s] = klass.instance
    end

    def self.delete(name)
      all.delete(name.to_s)
    end

    def self.all
      @formats ||= Hash.new(Base.instance)
    end

    def self.available_formats
      all.keys
    end

    def self.find(name)
      all[name.to_s]
    end

    # Return an array of custom field formats which can be used in select_tag
    def self.as_select(class_name=nil)
      formats = all.values.select do |format|
        format.class.customized_class_names.nil? || format.class.customized_class_names.include?(class_name)
      end
      formats.map {|format| [::I18n.t(format.label), format.name] }.sort_by(&:first)
    end

    class Base
      include Singleton
      include Redmine::I18n
      include Redmine::Helpers::URL
      include ERB::Util

      class_attribute :format_name
      self.format_name = nil

      # Set this to true if the format supports multiple values
      class_attribute :multiple_supported
      self.multiple_supported = false

      # Set this to true if the format supports textual search on custom values
      class_attribute :searchable_supported
      self.searchable_supported = false

      # Set this to true if field values can be summed up
      class_attribute :totalable_supported
      self.totalable_supported = false

      # Restricts the classes that the custom field can be added to
      # Set to nil for no restrictions
      class_attribute :customized_class_names
      self.customized_class_names = nil

      # Name of the partial for editing the custom field
      class_attribute :form_partial
      self.form_partial = nil

      class_attribute :change_as_diff
      self.change_as_diff = false

      def self.add(name)
        self.format_name = name
        Redmine::FieldFormat.add(name, self)
      end
      private_class_method :add

      def self.field_attributes(*args)
        CustomField.store_accessor :format_store, *args
      end

      field_attributes :url_pattern

      def name
        self.class.format_name
      end

      def label
        "label_#{name}"
      end

      def cast_custom_value(custom_value)
        cast_value(custom_value.custom_field, custom_value.value, custom_value.customized)
      end

      def cast_value(custom_field, value, customized=nil)
        if value.blank?
          nil
        elsif value.is_a?(Array)
          casted = value.map do |v|
            cast_single_value(custom_field, v, customized)
          end
          casted.compact.sort
        else
          cast_single_value(custom_field, value, customized)
        end
      end

      def cast_single_value(custom_field, value, customized=nil)
        value.to_s
      end

      def target_class
        nil
      end
 
      def possible_custom_value_options(custom_value)
        possible_values_options(custom_value.custom_field, custom_value.customized)
      end

      def possible_values_options(custom_field, object=nil)
        []
      end

      def value_from_keyword(custom_field, keyword, object)
        possible_values_options = possible_values_options(custom_field, object)
        if possible_values_options.present?
          keyword = keyword.to_s
          if v = possible_values_options.detect {|text, id| keyword.casecmp(text)  == 0}
            if v.is_a?(Array)
              v.last
            else
              v
            end
          end
        else
          keyword
        end
      end

      # Returns the validation errors for custom_field
      # Should return an empty array if custom_field is valid
      def validate_custom_field(custom_field)
        errors = []
        pattern = custom_field.url_pattern
        if pattern.present? && !uri_with_safe_scheme?(url_pattern_without_tokens(pattern))
          errors << [:url_pattern, :invalid]
        end
        errors
      end

      # Returns the validation error messages for custom_value
      # Should return an empty array if custom_value is valid
      def validate_custom_value(custom_value)
        values = Array.wrap(custom_value.value).reject {|value| value.to_s == ''}
        errors = values.map do |value|
          validate_single_value(custom_value.custom_field, value, custom_value.customized)
        end
        errors.flatten.uniq
      end

      def validate_single_value(custom_field, value, customized=nil)
        []
      end

      def formatted_custom_value(view, custom_value, html=false)
        formatted_value(view, custom_value.custom_field, custom_value.value, custom_value.customized, html)
      end

      def formatted_value(view, custom_field, value, customized=nil, html=false)
        casted = cast_value(custom_field, value, customized)
        if html && custom_field.url_pattern.present?
          texts_and_urls = Array.wrap(casted).map do |single_value|
            text = view.format_object(single_value, false).to_s
            url = url_from_pattern(custom_field, single_value, customized)
            [text, url]
          end
          links = texts_and_urls.sort_by(&:first).map {|text, url| view.link_to_if uri_with_safe_scheme?(url), text, url}
          links.join(', ').html_safe
        else
          casted
        end
      end

      # Returns an URL generated with the custom field URL pattern
      # and variables substitution:
      # %value% => the custom field value
      # %id% => id of the customized object
      # %project_id% => id of the project of the customized object if defined
      # %project_identifier% => identifier of the project of the customized object if defined
      # %m1%, %m2%... => capture groups matches of the custom field regexp if defined
      def url_from_pattern(custom_field, value, customized)
        url = custom_field.url_pattern.to_s.dup
        url.gsub!('%value%') {value.to_s}
        url.gsub!('%id%') {customized.id.to_s}
        url.gsub!('%project_id%') {(customized.respond_to?(:project) ? customized.project.try(:id) : nil).to_s}
        url.gsub!('%project_identifier%') {(customized.respond_to?(:project) ? customized.project.try(:identifier) : nil).to_s}
        if custom_field.regexp.present?
          url.gsub!(%r{%m(\d+)%}) do
            m = $1.to_i
            if matches ||= value.to_s.match(Regexp.new(custom_field.regexp))
              matches[m].to_s
            end
          end
        end
        URI.encode(url)
      end
      protected :url_from_pattern

      # Returns the URL pattern with substitution tokens removed,
      # for validation purpose
      def url_pattern_without_tokens(url_pattern)
        url_pattern.to_s.gsub(/%(value|id|project_id|project_identifier|m\d+)%/, '')
      end
      protected :url_pattern_without_tokens

      def edit_tag(view, tag_id, tag_name, custom_value, options={})
        view.text_field_tag(tag_name, custom_value.value, options.merge(:id => tag_id))
      end

      def bulk_edit_tag(view, tag_id, tag_name, custom_field, objects, value, options={})
        view.text_field_tag(tag_name, value, options.merge(:id => tag_id)) +
          bulk_clear_tag(view, tag_id, tag_name, custom_field, value)
      end

      def bulk_clear_tag(view, tag_id, tag_name, custom_field, value)
        if custom_field.is_required?
          ''.html_safe
        else
          view.content_tag('label',
            view.check_box_tag(tag_name, '__none__', (value == '__none__'), :id => nil, :data => {:disables => "##{tag_id}"}) + l(:button_clear),
            :class => 'inline'
          )
        end
      end
      protected :bulk_clear_tag

      def query_filter_options(custom_field, query)
        {:type => :string}
      end

      def before_custom_field_save(custom_field)
      end

      # Returns a ORDER BY clause that can used to sort customized
      # objects by their value of the custom field.
      # Returns nil if the custom field can not be used for sorting.
      def order_statement(custom_field)
        # COALESCE is here to make sure that blank and NULL values are sorted equally
        "COALESCE(#{join_alias custom_field}.value, '')"
      end

      # Returns a GROUP BY clause that can used to group by custom value
      # Returns nil if the custom field can not be used for grouping.
      def group_statement(custom_field)
        nil
      end

      # Returns a JOIN clause that is added to the query when sorting by custom values
      def join_for_order_statement(custom_field)
        alias_name = join_alias(custom_field)

        "LEFT OUTER JOIN #{CustomValue.table_name} #{alias_name}" +
          " ON #{alias_name}.customized_type = '#{custom_field.class.customized_class.base_class.name}'" +
          " AND #{alias_name}.customized_id = #{custom_field.class.customized_class.table_name}.id" +
          " AND #{alias_name}.custom_field_id = #{custom_field.id}" +
          " AND (#{custom_field.visibility_by_project_condition})" +
          " AND #{alias_name}.value <> ''" +
          " AND #{alias_name}.id = (SELECT max(#{alias_name}_2.id) FROM #{CustomValue.table_name} #{alias_name}_2" +
            " WHERE #{alias_name}_2.customized_type = #{alias_name}.customized_type" +
            " AND #{alias_name}_2.customized_id = #{alias_name}.customized_id" +
            " AND #{alias_name}_2.custom_field_id = #{alias_name}.custom_field_id)"
      end

      def join_alias(custom_field)
        "cf_#{custom_field.id}"
      end
      protected :join_alias
    end

    class Unbounded < Base
      def validate_single_value(custom_field, value, customized=nil)
        errs = super
        value = value.to_s
        unless custom_field.regexp.blank? or value =~ Regexp.new(custom_field.regexp)
          errs << ::I18n.t('activerecord.errors.messages.invalid')
        end
        if custom_field.min_length && value.length < custom_field.min_length
          errs << ::I18n.t('activerecord.errors.messages.too_short', :count => custom_field.min_length)
        end
        if custom_field.max_length && custom_field.max_length > 0 && value.length > custom_field.max_length
          errs << ::I18n.t('activerecord.errors.messages.too_long', :count => custom_field.max_length)
        end
        errs
      end
    end

    class StringFormat < Unbounded
      add 'string'
      self.searchable_supported = true
      self.form_partial = 'custom_fields/formats/string'
      field_attributes :text_formatting

      def formatted_value(view, custom_field, value, customized=nil, html=false)
        if html
          if custom_field.url_pattern.present?
            super
          elsif custom_field.text_formatting == 'full'
            view.textilizable(value, :object => customized)
          else
            value.to_s
          end
        else
          value.to_s
        end
      end
    end

    class TextFormat < Unbounded
      add 'text'
      self.searchable_supported = true
      self.form_partial = 'custom_fields/formats/text'
      self.change_as_diff = true

      def formatted_value(view, custom_field, value, customized=nil, html=false)
        if html
          if value.present?
            if custom_field.text_formatting == 'full'
              view.textilizable(value, :object => customized)
            else
              view.simple_format(html_escape(value))
            end
          else
            ''
          end
        else
          value.to_s
        end
      end

      def edit_tag(view, tag_id, tag_name, custom_value, options={})
        view.text_area_tag(tag_name, custom_value.value, options.merge(:id => tag_id, :rows => 3))
      end

      def bulk_edit_tag(view, tag_id, tag_name, custom_field, objects, value, options={})
        view.text_area_tag(tag_name, value, options.merge(:id => tag_id, :rows => 3)) +
          '<br />'.html_safe +
          bulk_clear_tag(view, tag_id, tag_name, custom_field, value)
      end

      def query_filter_options(custom_field, query)
        {:type => :text}
      end
    end

    class LinkFormat < StringFormat
      add 'link'
      self.searchable_supported = false
      self.form_partial = 'custom_fields/formats/link'

      def formatted_value(view, custom_field, value, customized=nil, html=false)
        if html && value.present?
          if custom_field.url_pattern.present?
            url = url_from_pattern(custom_field, value, customized)
          else
            url = value.to_s
            unless url =~ %r{\A[a-z]+://}i
              # no protocol found, use http by default
              url = "http://" + url
            end
          end
          view.link_to value.to_s.truncate(40), url
        else
          value.to_s
        end
      end
    end

    class Numeric < Unbounded
      self.form_partial = 'custom_fields/formats/numeric'
      self.totalable_supported = true

      def order_statement(custom_field)
        # Make the database cast values into numeric
        # Postgresql will raise an error if a value can not be casted!
        # CustomValue validations should ensure that it doesn't occur
        "CAST(CASE #{join_alias custom_field}.value WHEN '' THEN '0' ELSE #{join_alias custom_field}.value END AS decimal(30,3))"
      end

      # Returns totals for the given scope
      def total_for_scope(custom_field, scope)
        scope.joins(:custom_values).
          where(:custom_values => {:custom_field_id => custom_field.id}).
          where.not(:custom_values => {:value => ''}).
          sum("CAST(#{CustomValue.table_name}.value AS decimal(30,3))")
      end

      def cast_total_value(custom_field, value)
        cast_single_value(custom_field, value)
      end
    end

    class IntFormat < Numeric
      add 'int'

      def label
        "label_integer"
      end

      def cast_single_value(custom_field, value, customized=nil)
        value.to_i
      end

      def validate_single_value(custom_field, value, customized=nil)
        errs = super
        errs << ::I18n.t('activerecord.errors.messages.not_a_number') unless value.to_s =~ /^[+-]?\d+$/
        errs
      end

      def query_filter_options(custom_field, query)
        {:type => :integer}
      end

      def group_statement(custom_field)
        order_statement(custom_field)
      end
    end

    class FloatFormat < Numeric
      add 'float'

      def cast_single_value(custom_field, value, customized=nil)
        value.to_f
      end

      def cast_total_value(custom_field, value)
        value.to_f.round(2)
      end

      def validate_single_value(custom_field, value, customized=nil)
        errs = super
        errs << ::I18n.t('activerecord.errors.messages.invalid') unless (Kernel.Float(value) rescue nil)
        errs
      end

      def query_filter_options(custom_field, query)
        {:type => :float}
      end
    end

    class DateFormat < Unbounded
      add 'date'
      self.form_partial = 'custom_fields/formats/date'

      def cast_single_value(custom_field, value, customized=nil)
        value.to_date rescue nil
      end

      def validate_single_value(custom_field, value, customized=nil)
        if value =~ /^\d{4}-\d{2}-\d{2}$/ && (value.to_date rescue false)
          []
        else
          [::I18n.t('activerecord.errors.messages.not_a_date')]
        end
      end

      def edit_tag(view, tag_id, tag_name, custom_value, options={})
        view.date_field_tag(tag_name, custom_value.value, options.merge(:id => tag_id, :size => 10)) +
          view.calendar_for(tag_id)
      end

      def bulk_edit_tag(view, tag_id, tag_name, custom_field, objects, value, options={})
        view.date_field_tag(tag_name, value, options.merge(:id => tag_id, :size => 10)) +
          view.calendar_for(tag_id) +
          bulk_clear_tag(view, tag_id, tag_name, custom_field, value)
      end

      def query_filter_options(custom_field, query)
        {:type => :date}
      end

      def group_statement(custom_field)
        order_statement(custom_field)
      end
    end

    class List < Base
      self.multiple_supported = true
      field_attributes :edit_tag_style

      def edit_tag(view, tag_id, tag_name, custom_value, options={})
        if custom_value.custom_field.edit_tag_style == 'check_box'
          check_box_edit_tag(view, tag_id, tag_name, custom_value, options)
        else
          select_edit_tag(view, tag_id, tag_name, custom_value, options)
        end
      end

      def bulk_edit_tag(view, tag_id, tag_name, custom_field, objects, value, options={})
        opts = []
        opts << [l(:label_no_change_option), ''] unless custom_field.multiple?
        opts << [l(:label_none), '__none__'] unless custom_field.is_required?
        opts += possible_values_options(custom_field, objects)
        view.select_tag(tag_name, view.options_for_select(opts, value), options.merge(:multiple => custom_field.multiple?))
      end

      def query_filter_options(custom_field, query)
        {:type => :list_optional, :values => query_filter_values(custom_field, query)}
      end

      protected

      # Returns the values that are available in the field filter
      def query_filter_values(custom_field, query)
        possible_values_options(custom_field, query.project)
      end

      # Renders the edit tag as a select tag
      def select_edit_tag(view, tag_id, tag_name, custom_value, options={})
        blank_option = ''.html_safe
        unless custom_value.custom_field.multiple?
          if custom_value.custom_field.is_required?
            unless custom_value.custom_field.default_value.present?
              blank_option = view.content_tag('option', "--- #{l(:actionview_instancetag_blank_option)} ---", :value => '')
            end
          else
            blank_option = view.content_tag('option', '&nbsp;'.html_safe, :value => '')
          end
        end
        options_tags = blank_option + view.options_for_select(possible_custom_value_options(custom_value), custom_value.value)
        s = view.select_tag(tag_name, options_tags, options.merge(:id => tag_id, :multiple => custom_value.custom_field.multiple?))
        if custom_value.custom_field.multiple?
          s << view.hidden_field_tag(tag_name, '')
        end
        s
      end

      # Renders the edit tag as check box or radio tags
      def check_box_edit_tag(view, tag_id, tag_name, custom_value, options={})
        opts = []
        unless custom_value.custom_field.multiple? || custom_value.custom_field.is_required?
          opts << ["(#{l(:label_none)})", '']
        end
        opts += possible_custom_value_options(custom_value)
        s = ''.html_safe
        tag_method = custom_value.custom_field.multiple? ? :check_box_tag : :radio_button_tag
        opts.each do |label, value|
          value ||= label
          checked = (custom_value.value.is_a?(Array) && custom_value.value.include?(value)) || custom_value.value.to_s == value
          tag = view.send(tag_method, tag_name, value, checked, :id => tag_id)
          # set the id on the first tag only
          tag_id = nil
          s << view.content_tag('label', tag + ' ' + label) 
        end
        if custom_value.custom_field.multiple?
          s << view.hidden_field_tag(tag_name, '')
        end
        css = "#{options[:class]} check_box_group"
        view.content_tag('span', s, options.merge(:class => css))
      end
    end

    class ListFormat < List
      add 'list'
      self.searchable_supported = true
      self.form_partial = 'custom_fields/formats/list'

      def possible_custom_value_options(custom_value)
        options = possible_values_options(custom_value.custom_field)
        missing = [custom_value.value].flatten.reject(&:blank?) - options
        if missing.any?
          options += missing
        end
        options
      end

      def possible_values_options(custom_field, object=nil)
        custom_field.possible_values
      end

      def validate_custom_field(custom_field)
        errors = []
        errors << [:possible_values, :blank] if custom_field.possible_values.blank?
        errors << [:possible_values, :invalid] unless custom_field.possible_values.is_a? Array
        errors
      end

      def validate_custom_value(custom_value)
        values = Array.wrap(custom_value.value).reject {|value| value.to_s == ''}
        invalid_values = values - Array.wrap(custom_value.value_was) - custom_value.custom_field.possible_values
        if invalid_values.any?
          [::I18n.t('activerecord.errors.messages.inclusion')]
        else
          []
        end
      end

      def group_statement(custom_field)
        order_statement(custom_field)
      end
    end

    class BoolFormat < List
      add 'bool'
      self.multiple_supported = false
      self.form_partial = 'custom_fields/formats/bool'

      def label
        "label_boolean"
      end

      def cast_single_value(custom_field, value, customized=nil)
        value == '1' ? true : false
      end

      def possible_values_options(custom_field, object=nil)
        [[::I18n.t(:general_text_Yes), '1'], [::I18n.t(:general_text_No), '0']]
      end

      def group_statement(custom_field)
        order_statement(custom_field)
      end

      def edit_tag(view, tag_id, tag_name, custom_value, options={})
        case custom_value.custom_field.edit_tag_style
        when 'check_box'
          single_check_box_edit_tag(view, tag_id, tag_name, custom_value, options)
        when 'radio'
          check_box_edit_tag(view, tag_id, tag_name, custom_value, options)
        else
          select_edit_tag(view, tag_id, tag_name, custom_value, options)
        end
      end

      # Renders the edit tag as a simple check box
      def single_check_box_edit_tag(view, tag_id, tag_name, custom_value, options={})
        s = ''.html_safe
        s << view.hidden_field_tag(tag_name, '0', :id => nil)
        s << view.check_box_tag(tag_name, '1', custom_value.value.to_s == '1', :id => tag_id)
        view.content_tag('span', s, options)
      end
    end

    class RecordList < List
      self.customized_class_names = %w(Issue TimeEntry Version Document Project)

      def cast_single_value(custom_field, value, customized=nil)
        target_class.find_by_id(value.to_i) if value.present?
      end

      def target_class
        @target_class ||= self.class.name[/^(.*::)?(.+)Format$/, 2].constantize rescue nil
      end

      def reset_target_class
        @target_class = nil
      end
 
      def possible_custom_value_options(custom_value)
        options = possible_values_options(custom_value.custom_field, custom_value.customized)
        missing = [custom_value.value_was].flatten.reject(&:blank?) - options.map(&:last)
        if missing.any?
          options += target_class.where(:id => missing.map(&:to_i)).map {|o| [o.to_s, o.id.to_s]}
        end
        options
      end

      def order_statement(custom_field)
        if target_class.respond_to?(:fields_for_order_statement)
          target_class.fields_for_order_statement(value_join_alias(custom_field))
        end
      end

      def group_statement(custom_field)
        "COALESCE(#{join_alias custom_field}.value, '')"
      end

      def join_for_order_statement(custom_field)
        alias_name = join_alias(custom_field)

        "LEFT OUTER JOIN #{CustomValue.table_name} #{alias_name}" +
          " ON #{alias_name}.customized_type = '#{custom_field.class.customized_class.base_class.name}'" +
          " AND #{alias_name}.customized_id = #{custom_field.class.customized_class.table_name}.id" +
          " AND #{alias_name}.custom_field_id = #{custom_field.id}" +
          " AND (#{custom_field.visibility_by_project_condition})" +
          " AND #{alias_name}.value <> ''" +
          " AND #{alias_name}.id = (SELECT max(#{alias_name}_2.id) FROM #{CustomValue.table_name} #{alias_name}_2" +
            " WHERE #{alias_name}_2.customized_type = #{alias_name}.customized_type" +
            " AND #{alias_name}_2.customized_id = #{alias_name}.customized_id" +
            " AND #{alias_name}_2.custom_field_id = #{alias_name}.custom_field_id)" +
          " LEFT OUTER JOIN #{target_class.table_name} #{value_join_alias custom_field}" +
          " ON CAST(CASE #{alias_name}.value WHEN '' THEN '0' ELSE #{alias_name}.value END AS decimal(30,0)) = #{value_join_alias custom_field}.id"
      end

      def value_join_alias(custom_field)
        join_alias(custom_field) + "_" + custom_field.field_format
      end
      protected :value_join_alias
    end

    class EnumerationFormat < RecordList
      add 'enumeration'
      self.form_partial = 'custom_fields/formats/enumeration'
 
      def label
        "label_field_format_enumeration"
      end

      def target_class
        @target_class ||= CustomFieldEnumeration
      end

      def possible_values_options(custom_field, object=nil)
        possible_values_records(custom_field, object).map {|u| [u.name, u.id.to_s]}
      end

      def possible_values_records(custom_field, object=nil)
        custom_field.enumerations.active
      end

      def value_from_keyword(custom_field, keyword, object)
        value = custom_field.enumerations.where("LOWER(name) LIKE LOWER(?)", keyword).first
        value ? value.id : nil
      end
    end

    class UserFormat < RecordList
      add 'user'
      self.form_partial = 'custom_fields/formats/user'
      field_attributes :user_role

      def possible_values_options(custom_field, object=nil)
        possible_values_records(custom_field, object).map {|u| [u.name, u.id.to_s]}
      end

      def possible_values_records(custom_field, object=nil)
        if object.is_a?(Array)
          projects = object.map {|o| o.respond_to?(:project) ? o.project : nil}.compact.uniq
          projects.map {|project| possible_values_records(custom_field, project)}.reduce(:&) || []
        elsif object.respond_to?(:project) && object.project
          scope = object.project.users
          if custom_field.user_role.is_a?(Array)
            role_ids = custom_field.user_role.map(&:to_s).reject(&:blank?).map(&:to_i)
            if role_ids.any?
              scope = scope.where("#{Member.table_name}.id IN (SELECT DISTINCT member_id FROM #{MemberRole.table_name} WHERE role_id IN (?))", role_ids)
            end
          end
          scope.sorted
        else
          []
        end
      end

      def value_from_keyword(custom_field, keyword, object)
        users = possible_values_records(custom_field, object).to_a
        user = Principal.detect_by_keyword(users, keyword)
        user ? user.id : nil
      end

      def before_custom_field_save(custom_field)
        super
        if custom_field.user_role.is_a?(Array)
          custom_field.user_role.map!(&:to_s).reject!(&:blank?)
        end
      end
    end

    class VersionFormat < RecordList
      add 'version'
      self.form_partial = 'custom_fields/formats/version'
      field_attributes :version_status

      def possible_values_options(custom_field, object=nil)
        versions_options(custom_field, object)
      end

      def before_custom_field_save(custom_field)
        super
        if custom_field.version_status.is_a?(Array)
          custom_field.version_status.map!(&:to_s).reject!(&:blank?)
        end
      end

      protected

      def query_filter_values(custom_field, query)
        versions_options(custom_field, query.project, true)
      end

      def versions_options(custom_field, object, all_statuses=false)
        if object.is_a?(Array)
          projects = object.map {|o| o.respond_to?(:project) ? o.project : nil}.compact.uniq
          projects.map {|project| possible_values_options(custom_field, project)}.reduce(:&) || []
        elsif object.respond_to?(:project) && object.project
          scope = object.project.shared_versions
          filtered_versions_options(custom_field, scope, all_statuses)
        elsif object.nil?
          scope = Version.visible.where(:sharing => 'system')
          filtered_versions_options(custom_field, scope, all_statuses)
        else
          []
        end
      end

      def filtered_versions_options(custom_field, scope, all_statuses=false)
        if !all_statuses && custom_field.version_status.is_a?(Array)
          statuses = custom_field.version_status.map(&:to_s).reject(&:blank?)
          if statuses.any?
            scope = scope.where(:status => statuses.map(&:to_s))
          end
        end
        scope.sort.collect{|u| [u.to_s, u.id.to_s] }
      end
    end
  end
end
