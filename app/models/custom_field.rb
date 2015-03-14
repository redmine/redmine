# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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
  has_and_belongs_to_many :roles, :join_table => "#{table_name_prefix}custom_fields_roles#{table_name_suffix}", :foreign_key => "custom_field_id"
  acts_as_list :scope => 'type = \'#{self.class}\''
  serialize :possible_values
  store :format_store

  validates_presence_of :name, :field_format
  validates_uniqueness_of :name, :scope => :type
  validates_length_of :name, :maximum => 30
  validates_inclusion_of :field_format, :in => Proc.new { Redmine::FieldFormat.available_formats }
  validate :validate_custom_field
  attr_protected :id

  before_validation :set_searchable
  before_save do |field|
    field.format.before_custom_field_save(field)
  end
  after_save :handle_multiplicity_change
  after_save do |field|
    if field.visible_changed? && field.visible
      field.roles.clear
    end
  end

  scope :sorted, lambda { order(:position) }
  scope :visible, lambda {|*args|
    user = args.shift || User.current
    if user.admin?
      # nop
    elsif user.memberships.any?
      where("#{table_name}.visible = ? OR #{table_name}.id IN (SELECT DISTINCT cfr.custom_field_id FROM #{Member.table_name} m" +
        " INNER JOIN #{MemberRole.table_name} mr ON mr.member_id = m.id" +
        " INNER JOIN #{table_name_prefix}custom_fields_roles#{table_name_suffix} cfr ON cfr.role_id = mr.role_id" +
        " WHERE m.user_id = ?)",
        true, user.id)
    else
      where(:visible => true)
    end
  }

  def visible_by?(project, user=User.current)
    visible? || user.admin?
  end

  def format
    @format ||= Redmine::FieldFormat.find(field_format)
  end

  def field_format=(arg)
    # cannot change format of a saved custom field
    if new_record?
      @format = nil
      super
    end
  end

  def set_searchable
    # make sure these fields are not searchable
    self.searchable = false unless format.class.searchable_supported
    # make sure only these fields can have multiple values
    self.multiple = false unless format.class.multiple_supported
    true
  end

  def validate_custom_field
    format.validate_custom_field(self).each do |attribute, message|
      errors.add attribute, message
    end

    if regexp.present?
      begin
        Regexp.new(regexp)
      rescue
        errors.add(:regexp, :invalid)
      end
    end

    if default_value.present?
      validate_field_value(default_value).each do |message|
        errors.add :default_value, message
      end
    end
  end

  def possible_custom_value_options(custom_value)
    format.possible_custom_value_options(custom_value)
  end

  def possible_values_options(object=nil)
    if object.is_a?(Array)
      object.map {|o| format.possible_values_options(self, o)}.reduce(:&) || []
    else
      format.possible_values_options(self, object) || []
    end
  end

  def possible_values
    values = read_attribute(:possible_values)
    if values.is_a?(Array)
      values.each do |value|
        value.to_s.force_encoding('UTF-8')
      end
      values
    else
      []
    end
  end

  # Makes possible_values accept a multiline string
  def possible_values=(arg)
    if arg.is_a?(Array)
      values = arg.compact.map {|a| a.to_s.strip}.reject(&:blank?)
      write_attribute(:possible_values, values)
    else
      self.possible_values = arg.to_s.split(/[\n\r]+/)
    end
  end

  def cast_value(value)
    format.cast_value(self, value)
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
    format.order_statement(self)
  end

  # Returns a GROUP BY clause that can used to group by custom value
  # Returns nil if the custom field can not be used for grouping.
  def group_statement
    return nil if multiple?
    format.group_statement(self)
  end

  def join_for_order_statement
    format.join_for_order_statement(self)
  end

  def visibility_by_project_condition(project_key=nil, user=User.current, id_column=nil)
    if visible? || user.admin?
      "1=1"
    elsif user.anonymous?
      "1=0"
    else
      project_key ||= "#{self.class.customized_class.table_name}.project_id"
      id_column ||= id
      "#{project_key} IN (SELECT DISTINCT m.project_id FROM #{Member.table_name} m" +
        " INNER JOIN #{MemberRole.table_name} mr ON mr.member_id = m.id" +
        " INNER JOIN #{table_name_prefix}custom_fields_roles#{table_name_suffix} cfr ON cfr.role_id = mr.role_id" +
        " WHERE m.user_id = #{user.id} AND cfr.custom_field_id = #{id_column})"
    end
  end

  def self.visibility_condition
    if user.admin?
      "1=1"
    elsif user.anonymous?
      "#{table_name}.visible"
    else
      "#{project_key} IN (SELECT DISTINCT m.project_id FROM #{Member.table_name} m" +
        " INNER JOIN #{MemberRole.table_name} mr ON mr.member_id = m.id" +
        " INNER JOIN #{table_name_prefix}custom_fields_roles#{table_name_suffix} cfr ON cfr.role_id = mr.role_id" +
        " WHERE m.user_id = #{user.id} AND cfr.custom_field_id = #{id})"
    end
  end

  def <=>(field)
    position <=> field.position
  end

  # Returns the class that values represent
  def value_class
    format.target_class if format.respond_to?(:target_class)
  end

  def self.customized_class
    self.name =~ /^(.+)CustomField$/
    $1.constantize rescue nil
  end

  # to move in project_custom_field
  def self.for_all
    where(:is_for_all => true).order('position').to_a
  end

  def type_name
    nil
  end

  # Returns the error messages for the given value
  # or an empty array if value is a valid value for the custom field
  def validate_custom_value(custom_value)
    value = custom_value.value
    errs = []
    if value.is_a?(Array)
      if !multiple?
        errs << ::I18n.t('activerecord.errors.messages.invalid')
      end
      if is_required? && value.detect(&:present?).nil?
        errs << ::I18n.t('activerecord.errors.messages.blank')
      end
    else
      if is_required? && value.blank?
        errs << ::I18n.t('activerecord.errors.messages.blank')
      end
    end
    errs += format.validate_custom_value(custom_value)
    errs
  end

  # Returns the error messages for the default custom field value
  def validate_field_value(value)
    validate_custom_value(CustomFieldValue.new(:custom_field => self, :value => value))
  end

  # Returns true if value is a valid value for the custom field
  def valid_field_value?(value)
    validate_field_value(value).empty?
  end

  def format_in?(*args)
    args.include?(field_format)
  end

  protected

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

require_dependency 'redmine/field_format'
