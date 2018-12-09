# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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
    issue.notify = false

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
      if parent_issue_id =~ /\A(#)?(\d+)\z/
        parent_issue_id = $2.to_i
        if $1
          attributes['parent_issue_id'] = parent_issue_id
        else
          if parent_issue_id > item.position
            add_callback(parent_issue_id, 'set_as_parent', item.position)
          elsif issue_id = items.where(:position => parent_issue_id).first.try(:obj_id)
            attributes['parent_issue_id'] = issue_id
          end
        end
      else
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
      value = case v.custom_field.field_format
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
end
