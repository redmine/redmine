module TrackerTheWise
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
      return false if status.is_closed && !User.current.allowed_to?(:edit_after_close_issues, project)
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
  end
end