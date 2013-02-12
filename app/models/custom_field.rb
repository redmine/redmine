# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

class CustomField < ActiveRecord::Base
  include Redmine::SubclassFactory

  has_many :custom_values, :dependent => :delete_all
  acts_as_list :scope => 'type = \'#{self.class}\''
  serialize :possible_values

  validates_presence_of :name, :field_format
  validates_uniqueness_of :name, :scope => :type
  validates_length_of :name, :maximum => 30
  validates_inclusion_of :field_format, :in => Redmine::CustomFieldFormat.available_formats

  validate :validate_custom_field
  before_validation :set_searchable
  after_save :handle_multiplicity_change

  scope :sorted, lambda { order("#{table_name}.position ASC") }

  CUSTOM_FIELDS_TABS = [
    {:name => 'IssueCustomField', :partial => 'custom_fields/index',
     :label => :label_issue_plural},
    {:name => 'TimeEntryCustomField', :partial => 'custom_fields/index',
     :label => :label_spent_time},
    {:name => 'ProjectCustomField', :partial => 'custom_fields/index',
     :label => :label_project_plural},
    {:name => 'VersionCustomField', :partial => 'custom_fields/index',
     :label => :label_version_plural},
    {:name => 'UserCustomField', :partial => 'custom_fields/index',
     :label => :label_user_plural},
    {:name => 'GroupCustomField', :partial => 'custom_fields/index',
     :label => :label_group_plural},
    {:name => 'TimeEntryActivityCustomField', :partial => 'custom_fields/index',
     :label => TimeEntryActivity::OptionName},
    {:name => 'IssuePriorityCustomField', :partial => 'custom_fields/index',
     :label => IssuePriority::OptionName},
    {:name => 'DocumentCategoryCustomField', :partial => 'custom_fields/index',
     :label => DocumentCategory::OptionName}
  ]

  CUSTOM_FIELDS_NAMES = CUSTOM_FIELDS_TABS.collect{|v| v[:name]}

  def field_format=(arg)
    # cannot change format of a saved custom field
    super if new_record?
  end

  def set_searchable
    # make sure these fields are not searchable
    self.searchable = false if %w(int float date bool).include?(field_format)
    # make sure only these fields can have multiple values
    self.multiple = false unless %w(list user version).include?(field_format)
    true
  end

  def validate_custom_field
    if self.field_format == "list"
      errors.add(:possible_values, :blank) if self.possible_values.nil? || self.possible_values.empty?
      errors.add(:possible_values, :invalid) unless self.possible_values.is_a? Array
    end

    if regexp.present?
      begin
        Regexp.new(regexp)
      rescue
        errors.add(:regexp, :invalid)
      end
    end

    if default_value.present? && !valid_field_value?(default_value)
      errors.add(:default_value, :invalid)
    end
  end

  def possible_values_options(obj=nil)
    case field_format
    when 'user', 'version'
      if obj.respond_to?(:project) && obj.project
        case field_format
        when 'user'
          obj.project.users.sort.collect {|u| [u.to_s, u.id.to_s]}
        when 'version'
          obj.project.shared_versions.sort.collect {|u| [u.to_s, u.id.to_s]}
        end
      elsif obj.is_a?(Array)
        obj.collect {|o| possible_values_options(o)}.reduce(:&)
      else
        []
      end
    when 'bool'
      [[l(:general_text_Yes), '1'], [l(:general_text_No), '0']]
    else
      possible_values || []
    end
  end

  def possible_values(obj=nil)
    case field_format
    when 'user', 'version'
      possible_values_options(obj).collect(&:last)
    when 'bool'
      ['1', '0']
    else
      values = super()
      if values.is_a?(Array)
        values.each do |value|
          value.force_encoding('UTF-8') if value.respond_to?(:force_encoding)
        end
      end
      values || []
    end
  end

  # Makes possible_values accept a multiline string
  def possible_values=(arg)
    if arg.is_a?(Array)
      super(arg.compact.collect(&:strip).select {|v| !v.blank?})
    else
      self.possible_values = arg.to_s.split(/[\n\r]+/)
    end
  end

  def cast_value(value)
    casted = nil
    unless value.blank?
      case field_format
      when 'string', 'text', 'list'
        casted = value
      when 'date'
        casted = begin; value.to_date; rescue; nil end
      when 'bool'
        casted = (value == '1' ? true : false)
      when 'int'
        casted = value.to_i
      when 'float'
        casted = value.to_f
      when 'user', 'version'
        casted = (value.blank? ? nil : field_format.classify.constantize.find_by_id(value.to_i))
      end
    end
    casted
  end

  def value_from_keyword(keyword, customized)
    possible_values_options = possible_values_options(customized)
    if possible_values_options.present?
      keyword = keyword.to_s.downcase
      if v = possible_values_options.detect {|text, id| text.downcase == keyword}
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

  # Returns a ORDER BY clause that can used to sort customized
  # objects by their value of the custom field.
  # Returns nil if the custom field can not be used for sorting.
  def order_statement
    return nil if multiple?
    case field_format
      when 'string', 'text', 'list', 'date', 'bool'
        # COALESCE is here to make sure that blank and NULL values are sorted equally
        "COALESCE(#{join_alias}.value, '')"
      when 'int', 'float'
        # Make the database cast values into numeric
        # Postgresql will raise an error if a value can not be casted!
        # CustomValue validations should ensure that it doesn't occur
        "CAST(CASE #{join_alias}.value WHEN '' THEN '0' ELSE #{join_alias}.value END AS decimal(30,3))"
      when 'user', 'version'
        value_class.fields_for_order_statement(value_join_alias)
      else
        nil
    end
  end

  # Returns a GROUP BY clause that can used to group by custom value
  # Returns nil if the custom field can not be used for grouping.
  def group_statement
    return nil if multiple?
    case field_format
      when 'list', 'date', 'bool', 'int'
        order_statement
      when 'user', 'version'
        "COALESCE(#{join_alias}.value, '')"
      else
        nil
    end
  end

  def join_for_order_statement
    case field_format
      when 'user', 'version'
        "LEFT OUTER JOIN #{CustomValue.table_name} #{join_alias}" +
          " ON #{join_alias}.customized_type = '#{self.class.customized_class.base_class.name}'" +
          " AND #{join_alias}.customized_id = #{self.class.customized_class.table_name}.id" +
          " AND #{join_alias}.custom_field_id = #{id}" +
          " AND #{join_alias}.value <> ''" +
          " AND #{join_alias}.id = (SELECT max(#{join_alias}_2.id) FROM #{CustomValue.table_name} #{join_alias}_2" +
            " WHERE #{join_alias}_2.customized_type = #{join_alias}.customized_type" +
            " AND #{join_alias}_2.customized_id = #{join_alias}.customized_id" +
            " AND #{join_alias}_2.custom_field_id = #{join_alias}.custom_field_id)" +
          " LEFT OUTER JOIN #{value_class.table_name} #{value_join_alias}" +
          " ON CAST(CASE #{join_alias}.value WHEN '' THEN '0' ELSE #{join_alias}.value END AS decimal(30,0)) = #{value_join_alias}.id"
      when 'int', 'float'
        "LEFT OUTER JOIN #{CustomValue.table_name} #{join_alias}" +
          " ON #{join_alias}.customized_type = '#{self.class.customized_class.base_class.name}'" +
          " AND #{join_alias}.customized_id = #{self.class.customized_class.table_name}.id" +
          " AND #{join_alias}.custom_field_id = #{id}" +
          " AND #{join_alias}.value <> ''" +
          " AND #{join_alias}.id = (SELECT max(#{join_alias}_2.id) FROM #{CustomValue.table_name} #{join_alias}_2" +
            " WHERE #{join_alias}_2.customized_type = #{join_alias}.customized_type" +
            " AND #{join_alias}_2.customized_id = #{join_alias}.customized_id" +
            " AND #{join_alias}_2.custom_field_id = #{join_alias}.custom_field_id)"
      when 'string', 'text', 'list', 'date', 'bool'
        "LEFT OUTER JOIN #{CustomValue.table_name} #{join_alias}" +
          " ON #{join_alias}.customized_type = '#{self.class.customized_class.base_class.name}'" +
          " AND #{join_alias}.customized_id = #{self.class.customized_class.table_name}.id" +
          " AND #{join_alias}.custom_field_id = #{id}" +
          " AND #{join_alias}.id = (SELECT max(#{join_alias}_2.id) FROM #{CustomValue.table_name} #{join_alias}_2" +
            " WHERE #{join_alias}_2.customized_type = #{join_alias}.customized_type" +
            " AND #{join_alias}_2.customized_id = #{join_alias}.customized_id" +
            " AND #{join_alias}_2.custom_field_id = #{join_alias}.custom_field_id)"
      else
        nil
    end
  end

  def join_alias
    "cf_#{id}"
  end

  def value_join_alias
    join_alias + "_" + field_format
  end

  def <=>(field)
    position <=> field.position
  end

  # Returns the class that values represent
  def value_class
    case field_format
      when 'user', 'version'
        field_format.classify.constantize
      else
        nil
    end
  end

  def self.customized_class
    self.name =~ /^(.+)CustomField$/
    begin; $1.constantize; rescue nil; end
  end

  # to move in project_custom_field
  def self.for_all
    where(:is_for_all => true).order('position').all
  end

  def type_name
    nil
  end

  # Returns the error messages for the given value
  # or an empty array if value is a valid value for the custom field
  def validate_field_value(value)
    errs = []
    if value.is_a?(Array)
      if !multiple?
        errs << ::I18n.t('activerecord.errors.messages.invalid')
      end
      if is_required? && value.detect(&:present?).nil?
        errs << ::I18n.t('activerecord.errors.messages.blank')
      end
      value.each {|v| errs += validate_field_value_format(v)}
    else
      if is_required? && value.blank?
        errs << ::I18n.t('activerecord.errors.messages.blank')
      end
      errs += validate_field_value_format(value)
    end
    errs
  end

  # Returns true if value is a valid value for the custom field
  def valid_field_value?(value)
    validate_field_value(value).empty?
  end

  def format_in?(*args)
    args.include?(field_format)
  end

  protected

  # Returns the error message for the given value regarding its format
  def validate_field_value_format(value)
    errs = []
    if value.present?
      errs << ::I18n.t('activerecord.errors.messages.invalid') unless regexp.blank? or value =~ Regexp.new(regexp)
      errs << ::I18n.t('activerecord.errors.messages.too_short', :count => min_length) if min_length > 0 and value.length < min_length
      errs << ::I18n.t('activerecord.errors.messages.too_long', :count => max_length) if max_length > 0 and value.length > max_length

      # Format specific validations
      case field_format
      when 'int'
        errs << ::I18n.t('activerecord.errors.messages.not_a_number') unless value =~ /^[+-]?\d+$/
      when 'float'
        begin; Kernel.Float(value); rescue; errs << ::I18n.t('activerecord.errors.messages.invalid') end
      when 'date'
        errs << ::I18n.t('activerecord.errors.messages.not_a_date') unless value =~ /^\d{4}-\d{2}-\d{2}$/ && begin; value.to_date; rescue; false end
      when 'list'
        errs << ::I18n.t('activerecord.errors.messages.inclusion') unless possible_values.include?(value)
      end
    end
    errs
  end

  # Removes multiple values for the custom field after setting the multiple attribute to false
  # We kepp the value with the highest id for each customized object
  def handle_multiplicity_change
    if !new_record? && multiple_was && !multiple
      ids = custom_values.
        where("EXISTS(SELECT 1 FROM #{CustomValue.table_name} cve WHERE cve.custom_field_id = #{CustomValue.table_name}.custom_field_id" +
          " AND cve.customized_type = #{CustomValue.table_name}.customized_type AND cve.customized_id = #{CustomValue.table_name}.customized_id" +
          " AND cve.id > #{CustomValue.table_name}.id)").
        pluck(:id)

      if ids.any?
        custom_values.where(:id => ids).delete_all
      end
    end
  end
end
