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

class Journal < ActiveRecord::Base
  belongs_to :journalized, :polymorphic => true
  # added as a quick fix to allow eager loading of the polymorphic association
  # since always associated to an issue, for now
  belongs_to :issue, :foreign_key => :journalized_id

  belongs_to :user
  has_many :details, :class_name => "JournalDetail", :dependent => :delete_all
  attr_accessor :indice

  acts_as_event :title => Proc.new {|o| status = ((s = o.new_status) ? " (#{s})" : nil); "#{o.issue.tracker} ##{o.issue.id}#{status}: #{o.issue.subject}" },
                :description => :notes,
                :author => :user,
                :group => :issue,
                :type => Proc.new {|o| (s = o.new_status) ? (s.is_closed? ? 'issue-closed' : 'issue-edit') : 'issue-note' },
                :url => Proc.new {|o| {:controller => 'issues', :action => 'show', :id => o.issue.id, :anchor => "change-#{o.id}"}}

  acts_as_activity_provider :type => 'issues',
                            :author_key => :user_id,
                            :find_options => {:include => [{:issue => :project}, :details, :user],
                                              :conditions => "#{Journal.table_name}.journalized_type = 'Issue' AND" +
                                                             " (#{JournalDetail.table_name}.prop_key = 'status_id' OR #{Journal.table_name}.notes <> '')"}

  before_create :split_private_notes
  after_create :send_notification

  scope :visible, lambda {|*args|
    user = args.shift || User.current

    includes(:issue => :project).
      where(Issue.visible_condition(user, *args)).
      where("(#{Journal.table_name}.private_notes = ? OR (#{Project.allowed_to_condition(user, :view_private_notes, *args)}))", false)
  }

  def save(*args)
    # Do not save an empty journal
    (details.empty? && notes.blank?) ? false : super
  end

  # Returns journal details that are visible to user
  def visible_details(user=User.current)
    details.select do |detail|
      if detail.property == 'cf'
        field_id = detail.prop_key
        field = CustomField.find_by_id(field_id)
        field && field.visible_by?(project, user)
      elsif detail.property == 'relation'
        Issue.find_by_id(detail.value || detail.old_value).try(:visible?, user)
      else
        true
      end
    end
  end

  def each_notification(users, &block)
    if users.any?
      users_by_details_visibility = users.group_by do |user|
        visible_details(user)
      end
      users_by_details_visibility.each do |visible_details, users|
        if notes? || visible_details.any?
          yield(users)
        end
      end
    end
  end

  # Returns the new status if the journal contains a status change, otherwise nil
  def new_status
    c = details.detect {|detail| detail.prop_key == 'status_id'}
    (c && c.value) ? IssueStatus.find_by_id(c.value.to_i) : nil
  end

  def new_value_for(prop)
    c = details.detect {|detail| detail.prop_key == prop}
    c ? c.value : nil
  end

  def editable_by?(usr)
    usr && usr.logged? && (usr.allowed_to?(:edit_issue_notes, project) || (self.user == usr && usr.allowed_to?(:edit_own_issue_notes, project)))
  end

  def project
    journalized.respond_to?(:project) ? journalized.project : nil
  end

  def attachments
    journalized.respond_to?(:attachments) ? journalized.attachments : nil
  end

  # Returns a string of css classes
  def css_classes
    s = 'journal'
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

  private

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
        (Setting.notified_events.include?('issue_priority_updated') && new_value_for('priority_id').present?)
      )
      Mailer.deliver_issue_edit(self)
    end
  end
end
