# frozen_string_literal: true

# ActsAsWatchable
module Redmine
  module Acts
    module Watchable
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def acts_as_watchable(options = {})
          return if self.included_modules.include?(Redmine::Acts::Watchable::InstanceMethods)
          class_eval do
            has_many :watchers, :as => :watchable, :dependent => :delete_all
            has_many :watcher_users, :through => :watchers, :source => :user, :validate => false

            scope :watched_by, lambda { |principal|
              user_ids = Array(principal.id)
              user_ids |= principal.group_ids if principal.is_a?(User)
              user_ids.compact!

              joins(:watchers).
              where("#{Watcher.table_name}.user_id IN (?)", user_ids)
            }
          end
          send :include, Redmine::Acts::Watchable::InstanceMethods
        end
      end

      module InstanceMethods
        def self.included(base)
          base.extend ClassMethods
        end

        # Returns an array of users that are proposed as watchers
        def addable_watcher_users
          users = self.project.principals.assignable_watchers.sort - self.watcher_users
          if respond_to?(:visible?)
            users.reject! {|user| user.is_a?(User) && !visible?(user)}
          end
          users
        end

        # Adds user as a watcher
        def add_watcher(user)
          # Rails does not reset the has_many :through association
          watcher_users.reset
          self.watchers << Watcher.new(:user => user)
        end

        # Removes user from the watchers list
        def remove_watcher(user)
          return nil unless user && (user.is_a?(User) || user.is_a?(Group))
          # Rails does not reset the has_many :through association
          watcher_users.reset
          watchers.where(:user_id => user.id).delete_all
        end

        # Adds/removes watcher
        def set_watcher(user, watching=true)
          watching ? add_watcher(user) : remove_watcher(user)
        end

        # Overrides watcher_user_ids= to make user_ids uniq
        def watcher_user_ids=(user_ids)
          if user_ids.is_a?(Array)
            user_ids = user_ids.uniq
          end
          super user_ids
        end

        # Returns true if object is watched by +principal+, that is
        # either by a given group,
        # or by a given user or any of their groups
        def watched_by?(principal)
          return false unless principal

          user_ids = Array(principal.id)
          user_ids |= principal.group_ids if principal.is_a?(User)
          user_ids.compact!

          (self.watcher_user_ids & user_ids).any?
        end

        def notified_watchers
          notified = watcher_users.active.to_a
          notified = notified.map {|n| n.is_a?(Group) ? n.users.active : n}.flatten
          notified.uniq!
          notified.reject! {|user| user.mail.blank? || user.mail_notification == 'none'}
          if respond_to?(:visible?)
            notified.reject! {|user| !visible?(user)}
          end
          notified
        end

        # Returns an array of watchers' email addresses
        def watcher_recipients
          notified_watchers.collect(&:mail)
        end

        module ClassMethods; end
      end
    end
  end
end
