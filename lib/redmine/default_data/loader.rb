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

module Redmine
  module DefaultData
    class DataAlreadyLoaded < StandardError; end

    module Loader
      include Redmine::I18n

      class << self
        # Returns true if no data is already loaded in the database
        # otherwise false
        def no_data?
          !Role.where(:builtin => 0).exists? &&
            !Tracker.exists? &&
            !IssueStatus.exists? &&
            !Enumeration.exists? &&
            !Query.exists?
        end

        # Loads the default data
        # Raises a RecordNotSaved exception if something goes wrong
        def load(lang=nil, options={})
          raise DataAlreadyLoaded.new("Some configuration data is already loaded.") unless no_data?
          set_language_if_valid(lang)
          workflow = !(options[:workflow] == false)

          Role.transaction do
            # Roles
            manager = Role.create! :name => l(:default_role_manager),
                                   :issues_visibility => 'all',
                                   :users_visibility => 'all',
                                   :position => 1
            manager.permissions = manager.setable_permissions.collect {|p| p.name}
            manager.save!

            developer =
              Role.create!(
                :name => l(:default_role_developer),
                :position => 2,
                :permissions => [
                  :manage_versions,
                  :manage_categories,
                  :view_issues,
                  :add_issues,
                  :edit_issues,
                  :view_private_notes,
                  :set_notes_private,
                  :manage_issue_relations,
                  :manage_subtasks,
                  :add_issue_notes,
                  :save_queries,
                  :view_gantt,
                  :view_calendar,
                  :log_time,
                  :view_time_entries,
                  :view_news,
                  :comment_news,
                  :view_documents,
                  :view_wiki_pages,
                  :view_wiki_edits,
                  :edit_wiki_pages,
                  :delete_wiki_pages,
                  :view_messages,
                  :add_messages,
                  :edit_own_messages,
                  :view_files,
                  :manage_files,
                  :browse_repository,
                  :view_changesets,
                  :commit_access,
                  :manage_related_issues
                ]
              )
            reporter =
              Role.create!(
                :name => l(:default_role_reporter),
                :position => 3,
                :permissions => [
                  :view_issues,
                  :add_issues,
                  :add_issue_notes,
                  :save_queries,
                  :view_gantt,
                  :view_calendar,
                  :log_time,
                  :view_time_entries,
                  :view_news,
                  :comment_news,
                  :view_documents,
                  :view_wiki_pages,
                  :view_wiki_edits,
                  :view_messages,
                  :add_messages,
                  :edit_own_messages,
                  :view_files,
                  :browse_repository,
                  :view_changesets
                ]
              )
            Role.non_member.update_attribute :permissions, [:view_issues,
                                                            :add_issues,
                                                            :add_issue_notes,
                                                            :save_queries,
                                                            :view_gantt,
                                                            :view_calendar,
                                                            :view_time_entries,
                                                            :view_news,
                                                            :comment_news,
                                                            :view_documents,
                                                            :view_wiki_pages,
                                                            :view_wiki_edits,
                                                            :view_messages,
                                                            :add_messages,
                                                            :view_files,
                                                            :browse_repository,
                                                            :view_changesets]

            Role.anonymous.update_attribute :permissions, [:view_issues,
                                                           :view_gantt,
                                                           :view_calendar,
                                                           :view_time_entries,
                                                           :view_news,
                                                           :view_documents,
                                                           :view_wiki_pages,
                                                           :view_wiki_edits,
                                                           :view_messages,
                                                           :view_files,
                                                           :browse_repository,
                                                           :view_changesets]

            # Issue statuses
            new       = IssueStatus.create!(:name => l(:default_issue_status_new), :is_closed => false, :position => 1)
            in_progress  = IssueStatus.create!(:name => l(:default_issue_status_in_progress), :is_closed => false, :position => 2)
            resolved  = IssueStatus.create!(:name => l(:default_issue_status_resolved), :is_closed => false, :position => 3)
            feedback  = IssueStatus.create!(:name => l(:default_issue_status_feedback), :is_closed => false, :position => 4)
            closed    = IssueStatus.create!(:name => l(:default_issue_status_closed), :is_closed => true, :position => 5)
            rejected  = IssueStatus.create!(:name => l(:default_issue_status_rejected), :is_closed => true, :position => 6)

            # Trackers
            bug = Tracker.create!(:name => l(:default_tracker_bug), :default_status_id => new.id, :is_in_roadmap => false, :position => 1)
            feature = Tracker.create!(:name => l(:default_tracker_feature), :default_status_id => new.id, :is_in_roadmap => true, :position => 2)
            support = Tracker.create!(:name => l(:default_tracker_support), :default_status_id => new.id, :is_in_roadmap => false, :position => 3)

            # Set trackers as defaults for new projects
            Setting.default_projects_tracker_ids = [
              bug.id.to_s,
              feature.id.to_s,
              support.id.to_s
            ]

            if workflow
              # Workflow
              Tracker.all.each do |t|
                IssueStatus.all.each do |os|
                  IssueStatus.all.each do |ns|
                    unless os == ns
                      WorkflowTransition.
                        create!(:tracker_id => t.id, :role_id => manager.id,
                                :old_status_id => os.id,
                                :new_status_id => ns.id)
                    end
                  end
                end
              end

              Tracker.all.each do |t|
                [new, in_progress, resolved, feedback].each do |os|
                  [in_progress, resolved, feedback, closed].each do |ns|
                    unless os == ns
                      WorkflowTransition.
                        create!(:tracker_id => t.id, :role_id => developer.id,
                                :old_status_id => os.id,
                                :new_status_id => ns.id)
                    end
                  end
                end
              end

              Tracker.all.each do |t|
                [new, in_progress, resolved, feedback].each do |os|
                  [closed].each do |ns|
                    unless os == ns
                      WorkflowTransition.
                        create!(:tracker_id => t.id, :role_id => reporter.id,
                                :old_status_id => os.id, :new_status_id => ns.id)
                    end
                  end
                end
                WorkflowTransition.
                  create!(:tracker_id => t.id, :role_id => reporter.id,
                          :old_status_id => resolved.id,
                          :new_status_id => feedback.id)
              end
            end

            # Enumerations
            IssuePriority.create!(:name => l(:default_priority_low), :position => 1)
            IssuePriority.create!(:name => l(:default_priority_normal), :position => 2, :is_default => true)
            IssuePriority.create!(:name => l(:default_priority_high), :position => 3)
            IssuePriority.create!(:name => l(:default_priority_urgent), :position => 4)
            IssuePriority.create!(:name => l(:default_priority_immediate), :position => 5)

            DocumentCategory.create!(:name => l(:default_doc_category_user), :position => 1)
            DocumentCategory.create!(:name => l(:default_doc_category_tech), :position => 2)

            TimeEntryActivity.create!(:name => l(:default_activity_design), :position => 1)
            TimeEntryActivity.create!(:name => l(:default_activity_development), :position => 2)

            # Issue queries
            IssueQuery.create!(
              :name => l(:label_assigned_to_me_issues),
              :filters =>
                {
                  'status_id' => {:operator => 'o', :values => ['']},
                  'assigned_to_id' => {:operator => '=', :values => ['me']},
                  'project.status' => {:operator => '=', :values => ['1']}
                },
              :sort_criteria => [['priority', 'desc'], ['updated_on', 'desc']],
              :visibility => Query::VISIBILITY_PUBLIC
            )
            IssueQuery.create!(
              :name => l(:label_reported_issues),
              :filters =>
                {
                  'status_id' => {:operator => 'o', :values => ['']},
                  'author_id' => {:operator => '=', :values => ['me']},
                  'project.status' => {:operator => '=', :values => ['1']}
                },
              :sort_criteria => [['updated_on', 'desc']],
              :visibility => Query::VISIBILITY_PUBLIC
            )
            IssueQuery.create!(
              :name => l(:label_updated_issues),
              :filters =>
                {
                  'status_id' => {:operator => 'o', :values => ['']},
                  'updated_by' => {:operator => '=', :values => ['me']},
                  'project.status' => {:operator => '=', :values => ['1']}
                },
              :sort_criteria => [['updated_on', 'desc']],
              :visibility => Query::VISIBILITY_PUBLIC
            )
            IssueQuery.create!(
              :name => l(:label_watched_issues),
              :filters =>
                {
                  'status_id' => {:operator => 'o', :values => ['']},
                  'watcher_id' => {:operator => '=', :values => ['me']},
                  'project.status' => {:operator => '=', :values => ['1']},
                },
              :sort_criteria => [['updated_on', 'desc']],
              :visibility => Query::VISIBILITY_PUBLIC
            )

            # Project queries
            ProjectQuery.create!(
              :name => l(:label_my_projects),
              :filters =>
                {
                  'status' => {:operator => '=', :values => ['1']},
                  'id' => {:operator => '=', :values => ['mine']}
                },
              :visibility => Query::VISIBILITY_PUBLIC
            )
            ProjectQuery.create!(
              :name => l(:label_my_bookmarks),
              :filters =>
                {
                  'status' => {:operator => '=', :values => ['1']},
                  'id' => {:operator => '=', :values => ['bookmarks']}
                },
              :visibility => Query::VISIBILITY_PUBLIC
            )

            # Time entry queries
            TimeEntryQuery.create!(
              :name => l(:label_spent_time),
              :filters =>
                {
                  'spent_on' => {:operator => '*', :values => ['']},
                  'user_id' => {:operator => '=', :values => ['me']}
                },
              :sort_criteria => [['spent_on', 'desc']],
              :options => {:totalable_names => [:hours]},
              :visibility => Query::VISIBILITY_PUBLIC
            )
          end
          true
        end
      end
    end
  end
end
