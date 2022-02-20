# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

class IssueImport < Import
  AUTO_MAPPABLE_FIELDS = {
    'tracker' => 'field_tracker',
    'subject' => 'field_subject',
    'description' => 'field_description',
    'status' => 'field_status',
    'priority' => 'field_priority',
    'category' => 'field_category',
    'assigned_to' => 'field_assigned_to',
    'fixed_version' => 'field_fixed_version',
    'is_private' => 'field_is_private',
    'parent_issue_id' => 'field_parent_issue',
    'start_date' => 'field_start_date',
    'due_date' => 'field_due_date',
    'estimated_hours' => 'field_estimated_hours',
    'done_ratio' => 'field_done_ratio',
    'unique_id' => 'field_unique_id',
    'relation_duplicates' => 'label_duplicates',
    'relation_duplicated' => 'label_duplicated_by',
    'relation_blocks' => 'label_blocks',
    'relation_blocked' => 'label_blocked_by',
    'relation_relates' => 'label_relates_to',
    'relation_precedes' => 'label_precedes',
    'relation_follows' =>  'label_follows',
    'relation_copied_to' => 'label_copied_to',
    'relation_copied_from' => 'label_copied_from'
  }

  def self.menu_item
    :issues
  end

  def self.authorized?(user)
    user.allowed_to?(:import_issues, nil, :global => true)
  end

  # Returns the objects that were imported
  def saved_objects
    object_ids = saved_items.pluck(:obj_id)
    objects = Issue.where(:id => object_ids).order(:id).preload(:tracker, :priority, :status)
  end

  # Returns a scope of projects that user is allowed to
  # import issue to
  def allowed_target_projects
    Project.allowed_to(user, :import_issues)
  end

  def project
    project_id = mapping['project_id'].to_i
    allowed_target_projects.find_by_id(project_id) || allowed_target_projects.first
  end

  # Returns a scope of trackers that user is allowed to
  # import issue to
  def allowed_target_trackers
    Issue.allowed_target_trackers(project, user)
  end

  def tracker
    if mapping['tracker'].to_s =~ /\Avalue:(\d+)\z/
      tracker_id = $1.to_i
      allowed_target_trackers.find_by_id(tracker_id)
    end
  end

  # Returns true if missing categories should be created during the import
  def create_categories?
    user.allowed_to?(:manage_categories, project) &&
      mapping['create_categories'] == '1'
  end

  # Returns true if missing versions should be created during the import
  def create_versions?
    user.allowed_to?(:manage_versions, project) &&
      mapping['create_versions'] == '1'
  end

  def mappable_custom_fields
    if tracker
      issue = Issue.new
      issue.project = project
      issue.tracker = tracker
      issue.editable_custom_field_values(user).map(&:custom_field)
    elsif project
      project.all_issue_custom_fields
    else
      []
    end
  end

  private

  def build_object(row, item)
    issue = Issue.new
    issue.author = user
    issue.notify = !!ActiveRecord::Type::Boolean.new.cast(settings['notifications'])

    tracker_id = nil
    if tracker
      tracker_id = tracker.id
    elsif tracker_name = row_value(row, 'tracker')
      tracker_id = allowed_target_trackers.named(tracker_name).first.try(:id)
    end

    attributes = {
      'project_id' => mapping['project_id'],
      'tracker_id' => tracker_id,
      'subject' => row_value(row, 'subject'),
      'description' => row_value(row, 'description')
    }
    if status_name = row_value(row, 'status')
      if status_id = IssueStatus.named(status_name).first.try(:id)
        attributes['status_id'] = status_id
      end
    end
    issue.send :safe_attributes=, attributes, user

    attributes = {}
    if priority_name = row_value(row, 'priority')
      if priority_id = IssuePriority.active.named(priority_name).first.try(:id)
        attributes['priority_id'] = priority_id
      end
    end
    if issue.project && category_name = row_value(row, 'category')
      if category = issue.project.issue_categories.named(category_name).first
        attributes['category_id'] = category.id
      elsif create_categories?
        category = issue.project.issue_categories.build
        category.name = category_name
        if category.save
          attributes['category_id'] = category.id
        end
      end
    end
    if assignee_name = row_value(row, 'assigned_to')
      if assignee = Principal.detect_by_keyword(issue.assignable_users, assignee_name)
        attributes['assigned_to_id'] = assignee.id
      end
    end
    if issue.project && version_name = row_value(row, 'fixed_version')
      version =
        issue.project.versions.named(version_name).first ||
        issue.project.shared_versions.named(version_name).first
      if version
        attributes['fixed_version_id'] = version.id
      elsif create_versions?
        version = issue.project.versions.build
        version.name = version_name
        if version.save
          attributes['fixed_version_id'] = version.id
        end
      end
    end
    if is_private = row_value(row, 'is_private')
      if yes?(is_private)
        attributes['is_private'] = '1'
      end
    end
    if parent_issue_id = row_value(row, 'parent_issue_id')
      if parent_issue_id.start_with? '#'
        # refers to existing issue
        attributes['parent_issue_id'] = parent_issue_id[1..-1]
      elsif use_unique_id?
        # refers to other row with unique id
        issue_id = items.where(:unique_id => parent_issue_id).first.try(:obj_id)

        if issue_id
          attributes['parent_issue_id'] = issue_id
        else
          add_callback(parent_issue_id, 'set_as_parent', item.position)
        end
      elsif /\A\d+\z/.match?(parent_issue_id)
        # refers to other row by position
        parent_issue_id = parent_issue_id.to_i

        if parent_issue_id > item.position
          add_callback(parent_issue_id, 'set_as_parent', item.position)
        elsif issue_id = items.where(:position => parent_issue_id).first.try(:obj_id)
          attributes['parent_issue_id'] = issue_id
        end

      else
        # Something is odd. Assign parent_issue_id to trigger validation error
        attributes['parent_issue_id'] = parent_issue_id
      end
    end
    if start_date = row_date(row, 'start_date')
      attributes['start_date'] = start_date
    end
    if due_date = row_date(row, 'due_date')
      attributes['due_date'] = due_date
    end
    if estimated_hours = row_value(row, 'estimated_hours')
      attributes['estimated_hours'] = estimated_hours
    end
    if done_ratio = row_value(row, 'done_ratio')
      attributes['done_ratio'] = done_ratio
    end

    attributes['custom_field_values'] = issue.custom_field_values.inject({}) do |h, v|
      value =
        case v.custom_field.field_format
        when 'date'
          row_date(row, "cf_#{v.custom_field.id}")
        else
          row_value(row, "cf_#{v.custom_field.id}")
        end
      if value
        h[v.custom_field.id.to_s] = v.custom_field.value_from_keyword(value, issue)
      end
      h
    end

    issue.send :safe_attributes=, attributes, user

    if issue.tracker_id != tracker_id
      issue.tracker_id = nil
    end

    issue
  end

  def extend_object(row, item, issue)
    build_relations(row, item, issue)
  end

  def build_relations(row, item, issue)
    IssueRelation::TYPES.each_key do |type|
      has_delay = [IssueRelation::TYPE_PRECEDES, IssueRelation::TYPE_FOLLOWS].include?(type)

      if decls = relation_values(row, "relation_#{type}")
        decls.each do |decl|
          unless decl[:matches]
            # Invalid relation syntax - doesn't match regexp
            next
          end

          if decl[:delay] && !has_delay
            # Invalid relation syntax - delay for relation that doesn't support delays
            next
          end

          relation = IssueRelation.new(
            "relation_type" => type,
            "issue_from_id" => issue.id
          )

          if decl[:other_id]
            relation.issue_to_id = decl[:other_id]
          elsif decl[:other_pos]
            if use_unique_id?
              issue_id = items.where(:unique_id => decl[:other_pos]).first.try(:obj_id)
              if issue_id
                relation.issue_to_id = issue_id
              else
                add_callback(decl[:other_pos], 'set_relation', item.position, type, decl[:delay])
                next
              end
            elsif decl[:other_pos] > item.position
              add_callback(decl[:other_pos], 'set_relation', item.position, type, decl[:delay])
              next
            elsif issue_id = items.where(:position => decl[:other_pos]).first.try(:obj_id)
              relation.issue_to_id = issue_id
            end
          end

          relation.delay = decl[:delay] if decl[:delay]

          begin
            relation.save!
          rescue
            nil
          end
        end
      end
    end

    issue
  end

  def relation_values(row, name)
    content = row_value(row, name)

    return if content.blank?

    content.split(",").map do |declaration|
      declaration = declaration.strip

      # Valid expression:
      #
      # 123  => row 123 within the CSV
      # #123 => issue with ID 123
      #
      # For precedes and follows
      #
      # 123 7d    => row 123 within CSV with 7 day delay
      # #123  7d  => issue with ID 123 with 7 day delay
      # 123 -3d   => negative delay allowed
      #
      #
      # Invalid expression:
      #
      # No. 123 => Invalid leading letters
      # # 123   => Invalid space between # and issue number
      # 123 8h  => No other time units allowed (just days)
      #
      # Please note: If unique_id mapping is present, the whole line - but the
      # trailing delay expression - is considered unique_id.
      #
      # See examples at Rubular http://rubular.com/r/mgXM5Rp6zK
      #
      match = declaration.match(/\A(?<unique_id>(?<is_id>#)?(?<id>\d+)|.+?)(?:\s+(?<delay>-?\d+)d)?\z/)

      result = {
        :matches     => false,
        :declaration => declaration
      }

      if match
        result[:matches] = true
        result[:delay]   = match[:delay]

        if match[:is_id] && match[:id]
          result[:other_id] = match[:id]
        elsif use_unique_id? && match[:unique_id]
          result[:other_pos] = match[:unique_id]
        elsif match[:id]
          result[:other_pos] = match[:id].to_i
        else
          result[:matches] = false
        end
      end

      result
    end
  end

  # Callback that sets issue as the parent of a previously imported issue
  def set_as_parent_callback(issue, child_position)
    child_id = items.where(:position => child_position).first.try(:obj_id)
    return unless child_id

    child = Issue.find_by_id(child_id)
    return unless child

    child.parent_issue_id = issue.id
    child.save!
    issue.reload
  end

  def set_relation_callback(to_issue, from_position, type, delay)
    return if to_issue.new_record?

    from_id = items.where(:position => from_position).first.try(:obj_id)
    return unless from_id

    IssueRelation.create!(
      'relation_type' => type,
      'issue_from_id' => from_id,
      'issue_to_id'   => to_issue.id,
      'delay'         => delay
    )
    to_issue.reload
  end
end
