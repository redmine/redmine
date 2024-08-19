module IssuePatch
  extend ActiveSupport::Concern
  included do
    # validates :message_id, uniqueness: true, if: message_id.present?
    after_create :assign_watchers

    validates :message_id, uniqueness: true, if: -> { message_id.present? }
    scope :visible, lambda {|*args|
      joins(:project).joins("left join watchers wa on wa.watchable_id = issues.id")
                     .where(Issue.visible_condition(args.shift || User.current, *args))
                     .distinct
    }

    def assign_watchers
      [].tap do |watchers|
        if project.watcher_groups.present?
          watcher_groups = project.watcher_groups
          watcher_users = watcher_groups.map(&:user_ids).flatten
          watchers += watcher_users.uniq if watcher_users.present?
        elsif assigned_to_id.present?
          group = Group.find_by(id: assigned_to_id)
          group_users = group.users.pluck(:id) if group.present?
          watchers += group_users if group_users.present?
        else
          support_group = Group.find_by(lastname: 'Support')
          support_users = support_group.users.pluck(:id) if support_group.present?
          watchers += support_users if support_users.present?
        end
      end.each do |watcher|
        Watcher.create(watchable_type: 'Issue', watchable_id: id, user_id: watcher)
      end
    end

    def editable?(user=User.current)
      return false unless User.current.allowed_to?(:edit_after_close_issues, project)

      attributes_editable?(user) || notes_addable?(user)
    end

    def self.visible_condition(user, options={})
      Project.allowed_to_condition(user, :view_issues, options) do |role, user|
        sql = if user.id && user.logged?
          case role.issues_visibility
          when 'all'
            '1=1'
          when 'default'
            user_ids = [user.id] + user.groups.map(&:id).compact
            "(#{table_name}.is_private = #{connection.quoted_false} OR #{table_name}.author_id = #{user.id} OR #{table_name}.assigned_to_id IN (#{user_ids.join(',')}))"
          when 'own'
            user_ids = [user.id] + user.groups.map(&:id).compact
            "(#{table_name}.author_id = #{user.id} OR #{table_name}.assigned_to_id IN (#{user_ids.join(',')}))"
          else
            '1=0'
          end
        else
          "(#{table_name}.is_private = #{connection.quoted_false})"
        end
        unless role.permissions_all_trackers?(:view_issues)
          tracker_ids = role.permissions_tracker_ids(:view_issues)
          if tracker_ids.any?
            sql = "(#{sql} AND #{table_name}.tracker_id IN (#{tracker_ids.join(',')}))"
          else
            sql = '1=0'
          end
        end
        if role.allowed_to?(:view_only_watcher_issues)
          sql = "(#{sql} AND wa.user_id = #{user.id})"
        end
        sql
      end
    end

    # Returns true if usr or current user is allowed to view the issue
    def visible?(usr=nil)
      (usr || User.current).allowed_to?(:view_issues, self.project) do |role, user|
        visible = if user.logged?
          case role.issues_visibility
          when 'all'
            true
          when 'default'
            !self.is_private? || (self.author == user || user.is_or_belongs_to?(assigned_to))
          when 'own'
            self.author == user || user.is_or_belongs_to?(assigned_to)
          else
            false
          end
        else
          !self.is_private?
        end
        unless role.permissions_all_trackers?(:view_issues)
          visible &&= role.permissions_tracker_ids?(:view_issues, tracker_id)
        end
        if role.allowed_to?(:view_only_watcher_issues)
          visible &&= self.watched_by?(user)
        end
        visible
      end
    end

    def validate_issue
      if due_date && start_date && (start_date_changed? || due_date_changed?) && due_date < start_date
        errors.add :due_date, :greater_than_start_date
      end

      if start_date && start_date_changed? && soonest_start && start_date < soonest_start
        errors.add :start_date, :earlier_than_minimum_start_date, :date => format_date(soonest_start)
      end

      if project && fixed_version_id
        if fixed_version.nil? || assignable_versions.exclude?(fixed_version)
          errors.add :fixed_version_id, :inclusion
        elsif reopening? && fixed_version.closed?
          errors.add :base, I18n.t(:error_can_not_reopen_issue_on_closed_version)
        end
      end

      if project && category_id
        unless project.issue_category_ids.include?(category_id)
          errors.add :category_id, :inclusion
        end
      end

      # Checks that the issue can not be added/moved to a disabled tracker
      if project && (tracker_id_changed? || project_id_changed?)
        if tracker && !project.trackers.include?(tracker)
          errors.add :tracker_id, :inclusion
        end
      end

      if project && assigned_to_id_changed? && assigned_to_id.present?
        unless assignable_users.include?(assigned_to)
          errors.add :assigned_to_id, :invalid
        end
      end

      # Checks parent issue assignment
      if @invalid_parent_issue_id.present?
        errors.add :parent_issue_id, :invalid
      elsif @parent_issue
        if !valid_parent_project?(@parent_issue)
          errors.add :parent_issue_id, :invalid
        elsif (@parent_issue != parent) && (
            self.would_reschedule?(@parent_issue) ||
            @parent_issue.self_and_ancestors.any? do |a|
              a.relations_from.any? do |r|
                r.relation_type == IssueRelation::TYPE_PRECEDES &&
                  r.issue_to.would_reschedule?(self)
              end
            end
          )
          errors.add :parent_issue_id, :invalid
        # Comment out this block to allow attaching an open issue to a closed parent
        # elsif !closed? && @parent_issue.closed?
        #   # cannot attach an open issue to a closed parent
        #   errors.add :base, :open_issue_with_closed_parent
        elsif !new_record?
          # moving an existing issue
          if move_possible?(@parent_issue)
            # move accepted
          else
            errors.add :parent_issue_id, :invalid
          end
        end
      end
    end

  end
end