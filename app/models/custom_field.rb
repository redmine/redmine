# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
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

  def initialize(attributes=nil, *args)
    super
    self.possible_values ||= []
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
      values
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

  # Returns a ORDER BY clause that can used to sort customized
  # objects by their value of the custom field.
  # Returns false, if the custom field can not be used for sorting.
  def order_statement
    return nil if multiple?
    case field_format
      when 'string', 'text', 'list', 'date', 'bool'
        # COALESCE is here to make sure that blank and NULL values are sorted equally
        "COALESCE((SELECT cv_sort.value FROM #{CustomValue.table_name} cv_sort" +
          " WHERE cv_sort.customized_type='#{self.class.customized_class.name}'" +
          " AND cv_sort.customized_id=#{self.class.customized_class.table_name}.id" +
          " AND cv_sort.custom_field_id=#{id} LIMIT 1), '')"
      when 'int', 'float'
        # Make the database cast values into numeric
        # Postgresql will raise an error if a value can not be casted!
        # CustomValue validations should ensure that it doesn't occur
        "(SELECT CAST(cv_sort.value AS decimal(60,3)) FROM #{CustomValue.table_name} cv_sort" +
          " WHERE cv_sort.customized_type='#{self.class.customized_class.name}'" +
          " AND cv_sort.customized_id=#{self.class.customized_class.table_name}.id" +
          " AND cv_sort.custom_field_id=#{id} AND cv_sort.value <> '' AND cv_sort.value IS NOT NULL LIMIT 1)"
      else
        nil
    end
  end

  def <=>(field)
    position <=> field.position
  end

  def self.customized_class
    self.name =~ /^(.+)CustomField$/
    begin; $1.constantize; rescue nil; end
  end

  # to move in project_custom_field
  def self.for_all
    find(:all, :conditions => ["is_for_all=?", true], :order => 'position')
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
end
