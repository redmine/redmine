# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class Journal < ActiveRecord::Base
  include Redmine::SafeAttributes

  belongs_to :journalized, :polymorphic => true
  # added as a quick fix to allow eager loading of the polymorphic association
  # since always associated to an issue, for now
  belongs_to :issue, :foreign_key => :journalized_id

  belongs_to :user
  has_many :details, :class_name => "JournalDetail", :dependent => :delete_all, :inverse_of => :journal
  attr_accessor :indice

  acts_as_event :title => Proc.new {|o| status = ((s = o.new_status) ? " (#{s})" : nil); "#{o.issue.tracker} ##{o.issue.id}#{status}: #{o.issue.subject}" },
                :description => :notes,
                :author => :user,
                :group => :issue,
                :type => Proc.new {|o| (s = o.new_status) ? (s.is_closed? ? 'issue-closed' : 'issue-edit') : 'issue-note' },
                :url => Proc.new {|o| {:controller => 'issues', :action => 'show', :id => o.issue.id, :anchor => "change-#{o.id}"}}

  acts_as_activity_provider :type => 'issues',
                            :author_key => :user_id,
                            :scope => preload({:issue => :project}, :user).
                                      joins("LEFT OUTER JOIN #{JournalDetail.table_name} ON #{JournalDetail.table_name}.journal_id = #{Journal.table_name}.id").
                                      where("#{Journal.table_name}.journalized_type = 'Issue' AND" +
                                            " (#{JournalDetail.table_name}.prop_key = 'status_id' OR #{Journal.table_name}.notes <> '')").distinct

  before_create :split_private_notes
  after_create_commit :send_notification

  scope :visible, lambda {|*args|
    user = args.shift || User.current
    options = args.shift || {}

    joins(:issue => :project).
      where(Issue.visible_condition(user, options)).
      where(Journal.visible_notes_condition(user, :skip_pre_condition => true))
  }

  safe_attributes(
    'notes',
    :if => lambda {|journal, user| journal.new_record? || journal.editable_by?(user)})
  safe_attributes(
    'private_notes',
    :if => lambda {|journal, user| user.allowed_to?(:set_notes_private, journal.project)})

  # Returns a SQL condition to filter out journals with notes that are not visible to user
  def self.visible_notes_condition(user=User.current, options={})
    private_notes_permission = Project.allowed_to_condition(user, :view_private_notes, options)
    sanitize_sql_for_conditions(["(#{table_name}.private_notes = ? OR #{table_name}.user_id = ? OR (#{private_notes_permission}))", false, user.id])
  end

  def initialize(*args)
    super
    if journalized
      if journalized.new_record?
        self.notify = false
      else
        start
      end
    end
  end

  def save(*args)
    journalize_changes
    # Do not save an empty journal
    (details.empty? && notes.blank?) ? false : super
  end

  # Returns journal details that are visible to user
  def visible_details(user=User.current)
    details.select do |detail|
      if detail.property == 'cf'
        detail.custom_field && detail.custom_field.visible_by?(project, user)
      elsif detail.property == 'relation'
        Issue.find_by_id(detail.value || detail.old_value).try(:visible?, user)
      else
        true
      end
    end
  end

  # Returns the JournalDetail for the given attribute, or nil if the attribute
  # was not updated
  def detail_for_attribute(attribute)
    details.detect {|detail| detail.prop_key == attribute}
  end

  # Returns the new status if the journal contains a status change, otherwise nil
  def new_status
    s = new_value_for('status_id')
    s ? IssueStatus.find_by_id(s.to_i) : nil
  end

  def new_value_for(prop)
    detail_for_attribute(prop).try(:value)
  end

  def editable_by?(usr)
    usr && usr.logged? && (usr.allowed_to?(:edit_issue_notes, project) || (self.user == usr && usr.allowed_to?(:edit_own_issue_notes, project)))
  end

  def project
    journalized.respond_to?(:project) ? journalized.project : nil
  end

  def attachments
    journalized.respond_to?(:attachments) ? journalized.attachments : []
  end

  # Returns a string of css classes
  def css_classes
    s = +'journal'
    s << ' has-notes' unless notes.blank?
    s << ' has-details' unless details.blank?
    s << ' private-notes' if private_notes?
    s
  end

  def notify?
    @notify != false
  end

  def notify=(arg)
    @notify = arg
  end

  def notified_users
    notified = journalized.notified_users
    if private_notes?
      notified = notified.select {|user| user.allowed_to?(:view_private_notes, journalized.project)}
    end
    notified
  end

  def recipients
    notified_users.map(&:mail)
  end

  def notified_watchers
    notified = journalized.notified_watchers
    if private_notes?
      notified = notified.select {|user| user.allowed_to?(:view_private_notes, journalized.project)}
    end
    notified
  end

  def watcher_recipients
    notified_watchers.map(&:mail)
  end

  # Sets @custom_field instance variable on journals details using a single query
  def self.preload_journals_details_custom_fields(journals)
    field_ids = journals.map(&:details).flatten.select {|d| d.property == 'cf'}.map(&:prop_key).uniq
    if field_ids.any?
      fields_by_id = CustomField.where(:id => field_ids).inject({}) {|h, f| h[f.id] = f; h}
      journals.each do |journal|
        journal.details.each do |detail|
          if detail.property == 'cf'
            detail.instance_variable_set "@custom_field", fields_by_id[detail.prop_key.to_i]
          end
        end
      end
    end
    journals
  end

  # Stores the values of the attributes and custom fields of the journalized object
  def start
    if journalized
      @attributes_before_change = journalized.journalized_attribute_names.inject({}) do |h, attribute|
        h[attribute] = journalized.send(attribute)
        h
      end
      @custom_values_before_change = journalized.custom_field_values.inject({}) do |h, c|
        h[c.custom_field_id] = c.value
        h
      end
    end
    self
  end

  # Adds a journal detail for an attachment that was added or removed
  def journalize_attachment(attachment, added_or_removed)
    key = (added_or_removed == :removed ? :old_value : :value)
    details << JournalDetail.new(
        :property => 'attachment',
        :prop_key => attachment.id,
        key => attachment.filename
      )
  end

  # Adds a journal detail for an issue relation that was added or removed
  def journalize_relation(relation, added_or_removed)
    key = (added_or_removed == :removed ? :old_value : :value)
    details << JournalDetail.new(
        :property  => 'relation',
        :prop_key  => relation.relation_type_for(journalized),
        key => relation.other_issue(journalized).try(:id)
      )
  end

  private

  # Generates journal details for attribute and custom field changes
  def journalize_changes
    # attributes changes
    if @attributes_before_change
      attrs = (journalized.journalized_attribute_names + @attributes_before_change.keys).uniq
      attrs.each do |attribute|
        before = @attributes_before_change[attribute]
        after = journalized.send(attribute)
        next if before == after || (before.blank? && after.blank?)
        add_attribute_detail(attribute, before, after)
      end
    end
    # custom fields changes
    if @custom_values_before_change
      values_by_custom_field_id = {}
      @custom_values_before_change.each do |custom_field_id, value|
        values_by_custom_field_id[custom_field_id] = nil
      end
      journalized.custom_field_values.each do |c|
        values_by_custom_field_id[c.custom_field_id] = c.value
      end

      values_by_custom_field_id.each do |custom_field_id, after|
        before = @custom_values_before_change[custom_field_id]
        next if before == after || (before.blank? && after.blank?)

        if before.is_a?(Array) || after.is_a?(Array)
          before = [before] unless before.is_a?(Array)
          after = [after] unless after.is_a?(Array)

          # values removed
          (before - after).reject(&:blank?).each do |value|
            add_custom_field_detail(custom_field_id, value, nil)
          end
          # values added
          (after - before).reject(&:blank?).each do |value|
            add_custom_field_detail(custom_field_id, nil, value)
          end
        else
          add_custom_field_detail(custom_field_id, before, after)
        end
      end
    end
    start
  end

  # Adds a journal detail for an attribute change
  def add_attribute_detail(attribute, old_value, value)
    add_detail('attr', attribute, old_value, value)
  end

  # Adds a journal detail for a custom field value change
  def add_custom_field_detail(custom_field_id, old_value, value)
    add_detail('cf', custom_field_id, old_value, value)
  end

  # Adds a journal detail
  def add_detail(property, prop_key, old_value, value)
    details << JournalDetail.new(
        :property => property,
        :prop_key => prop_key,
        :old_value => old_value,
        :value => value
      )
  end

  def split_private_notes
    if private_notes?
      if notes.present?
        if details.any?
          # Split the journal (notes/changes) so we don't have half-private journals
          journal = Journal.new(:journalized => journalized, :user => user, :notes => nil, :private_notes => false)
          journal.details = details
          journal.save
          self.details = []
          self.created_on = journal.created_on
        end
      else
        # Blank notes should not be private
        self.private_notes = false
      end
    end
    true
  end

  def send_notification
    if notify? && (Setting.notified_events.include?('issue_updated') ||
        (Setting.notified_events.include?('issue_note_added') && notes.present?) ||
        (Setting.notified_events.include?('issue_status_updated') && new_status.present?) ||
        (Setting.notified_events.include?('issue_assigned_to_updated') && detail_for_attribute('assigned_to_id').present?) ||
        (Setting.notified_events.include?('issue_priority_updated') && new_value_for('priority_id').present?) ||
        (Setting.notified_events.include?('issue_fixed_version_updated') && detail_for_attribute('fixed_version_id').present?)
      )
      Mailer.deliver_issue_edit(self)
    end
  end
end
